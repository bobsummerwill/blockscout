defmodule Explorer.ChainData.EthereumJSONRPC do
  @moduledoc """
  `Explorer.ChainData` implementation backed by the current
  `EthereumJSONRPC` integration.
  """

  @behaviour Explorer.ChainData

  import EthereumJSONRPC, only: [integer_to_quantity: 1, json_rpc: 2, request: 1]

  alias EthereumJSONRPC.{Blocks, Logs, Receipts}
  alias EthereumJSONRPC.Receipts.ByTransactionHash

  alias Explorer.ChainData.{
    Balance,
    BlockBatch,
    Call,
    Code,
    InternalTransaction,
    Log,
    Nonce,
    Receipt
  }

  @impl Explorer.ChainData
  def chain_info(opts) do
    named_arguments = json_rpc_named_arguments(opts)

    with {:ok, chain_id} <- EthereumJSONRPC.fetch_chain_id(named_arguments),
         {:ok, head} <- EthereumJSONRPC.fetch_block_number_by_tag("latest", named_arguments) do
      safe_head =
        case EthereumJSONRPC.fetch_block_number_by_tag("safe", named_arguments) do
          {:ok, safe} -> safe
          _ -> nil
        end

      {:ok, %{chain_id: chain_id, head: head, safe_head: safe_head}}
    end
  end

  @impl Explorer.ChainData
  def block_by_tag(tag, opts) do
    with {:ok, %Blocks{} = blocks} <- EthereumJSONRPC.fetch_block_by_tag(to_tag(tag), json_rpc_named_arguments(opts)) do
      {:ok, blocks_to_batch(blocks) |> Map.get(:blocks) |> List.first()}
    end
  end

  @impl Explorer.ChainData
  def blocks_by_range(range, hydrated?, opts) do
    with {:ok, %Blocks{} = blocks} <- fetch_blocks_by_range(range, hydrated?, json_rpc_named_arguments(opts)) do
      {:ok, blocks_to_batch(blocks)}
    end
  end

  @impl Explorer.ChainData
  def blocks_by_hashes(hashes, hydrated?, opts) do
    with {:ok, %Blocks{} = blocks} <-
           EthereumJSONRPC.fetch_blocks_by_hash(hashes, json_rpc_named_arguments(opts), hydrated?) do
      {:ok, blocks_to_batch(blocks)}
    end
  end

  @impl Explorer.ChainData
  def transactions_by_hashes([], _opts), do: {:ok, [], []}

  @impl Explorer.ChainData
  def transactions_by_hashes(hashes, opts) do
    named_arguments = json_rpc_named_arguments(opts)

    requests =
      hashes
      |> Enum.with_index()
      |> Enum.map(fn {hash, id} ->
        request(%{id: id, method: "eth_getTransactionByHash", params: [hash]})
      end)

    with {:ok, responses} <- json_rpc(requests, named_arguments) do
      sanitized = EthereumJSONRPC.sanitize_responses(responses, Enum.to_list(0..(length(hashes) - 1)))

      {transactions, errors} =
        sanitized
        |> Enum.sort_by(& &1.id)
        |> Enum.reduce({[], []}, fn
          %{result: nil}, {transactions, errors} ->
            {[nil | transactions], errors}

          %{result: result}, {transactions, errors} when is_map(result) ->
            elixir_transaction = EthereumJSONRPC.Transaction.to_elixir(result)
            params = EthereumJSONRPC.Transaction.elixir_to_params(elixir_transaction)
            {[transaction_from_params(params, result) | transactions], errors}

          %{error: error}, {transactions, errors} ->
            {[nil | transactions], [error | errors]}
        end)

      {:ok, Enum.reverse(transactions), Enum.reverse(errors)}
    end
  end

  @impl Explorer.ChainData
  def receipts_by_block_numbers([], _opts), do: {:ok, %Receipt.Batch{}}

  @impl Explorer.ChainData
  def receipts_by_block_numbers(block_numbers, opts) do
    with {:ok, %{logs: logs, receipts: receipts}} <-
           Receipts.fetch_by_block_numbers(block_numbers, json_rpc_named_arguments(opts)) do
      {:ok,
       %Receipt.Batch{
         receipts: Enum.map(receipts, &receipt_from_params(&1, logs)),
         logs: Enum.map(logs, &log_from_params/1),
         raw: %{receipts: receipts, logs: logs}
       }}
    end
  end

  @impl Explorer.ChainData
  def receipts_by_transaction_hashes([], _opts), do: {:ok, %Receipt.Batch{}}

  @impl Explorer.ChainData
  def receipts_by_transaction_hashes(hashes, opts) do
    named_arguments = json_rpc_named_arguments(opts)

    requests =
      hashes
      |> Enum.with_index()
      |> Enum.map(fn {hash, id} -> ByTransactionHash.request(id, hash) end)

    with {:ok, raw_responses} <- json_rpc(requests, named_arguments),
         {:ok, responses} <- process_receipt_hash_responses(raw_responses, hashes) do
      elixir_receipts = Receipts.to_elixir(responses)
      receipt_params = Receipts.elixir_to_params(elixir_receipts)
      log_params = elixir_receipts |> Receipts.elixir_to_logs() |> Logs.elixir_to_params()

      {:ok,
       %Receipt.Batch{
         receipts: Enum.map(receipt_params, &receipt_from_params(&1, log_params)),
         logs: Enum.map(log_params, &log_from_params/1),
         raw: %{receipts: receipt_params, logs: log_params}
       }}
    end
  end

  @impl Explorer.ChainData
  def logs(%Log.Query{} = query, opts) do
    request =
      Logs.request(0, query_to_rpc_params(query))

    with {:ok, responses} <- json_rpc([request], json_rpc_named_arguments(opts)),
         {:ok, logs} <- Logs.from_responses(responses) do
      {:ok, Enum.map(logs, &log_from_params/1)}
    end
  end

  @impl Explorer.ChainData
  def balances_at(requests, opts) do
    rpc_requests =
      Enum.map(requests, fn %Balance.Request{address_hash: address_hash, block_number: block_number} ->
        %{hash_data: address_hash, block_quantity: quantity_or_tag(block_number)}
      end)

    with {:ok, fetched_balances} <- EthereumJSONRPC.fetch_balances(rpc_requests, json_rpc_named_arguments(opts)) do
      {:ok,
       %Balance.Batch{
         balances: Enum.map(fetched_balances.params_list, &balance_from_params/1),
         errors: fetched_balances.errors
       }}
    end
  end

  @impl Explorer.ChainData
  def nonces_at(requests, opts) do
    rpc_requests =
      Enum.map(requests, fn %Nonce.Request{address_hash: address_hash, block_number: block_number} ->
        %{address: address_hash, block_quantity: quantity_or_tag(block_number)}
      end)

    with {:ok, fetched_nonces} <- EthereumJSONRPC.fetch_nonces(rpc_requests, json_rpc_named_arguments(opts)) do
      {:ok,
       %Nonce.Batch{
         nonces: Enum.map(fetched_nonces.params_list, &nonce_from_params/1),
         errors: fetched_nonces.errors
       }}
    end
  end

  @impl Explorer.ChainData
  def codes_at(requests, opts) do
    rpc_requests =
      Enum.map(requests, fn %Code.Request{address_hash: address_hash, block_number: block_number} ->
        %{address: address_hash, block_quantity: quantity_or_tag(block_number)}
      end)

    with {:ok, fetched_codes} <- EthereumJSONRPC.fetch_codes(rpc_requests, json_rpc_named_arguments(opts)) do
      {:ok,
       %Code.Batch{
         codes: Enum.map(fetched_codes.params_list, &code_from_params/1),
         errors: fetched_codes.errors
       }}
    end
  end

  @impl Explorer.ChainData
  def contract_calls(requests, abi, opts) do
    rpc_requests =
      Enum.map(requests, fn %Call.Request{} = request ->
        request
        |> Map.from_struct()
        |> Map.drop([:from])
        |> maybe_put_from(request.from)
      end)

    EthereumJSONRPC.execute_contract_functions(rpc_requests, abi, json_rpc_named_arguments(opts))
  end

  @impl Explorer.ChainData
  def internal_transactions_by_block_numbers(block_numbers, opts) do
    case EthereumJSONRPC.fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments(opts)) do
      {:ok, params_list} ->
        {:ok, Enum.map(params_list, &%InternalTransaction{params: &1})}

      other ->
        other
    end
  end

  @impl Explorer.ChainData
  def raw_traces_by_transaction(transaction, opts) do
    EthereumJSONRPC.fetch_transaction_raw_traces(transaction, json_rpc_named_arguments(opts))
  end

  @impl Explorer.ChainData
  def subscribe_new_blocks(opts) do
    subscribe_named_arguments =
      opts
      |> json_rpc_named_arguments()
      |> Keyword.take([:transport, :transport_options, :variant])

    EthereumJSONRPC.subscribe("newHeads", [], subscribe_named_arguments)
  end

  defp fetch_blocks_by_range(range, true, named_arguments), do: EthereumJSONRPC.fetch_blocks_by_range(range, named_arguments)

  defp fetch_blocks_by_range(range, false, named_arguments) do
    EthereumJSONRPC.fetch_blocks_by_numbers(Enum.to_list(range), named_arguments, false)
  end

  defp blocks_to_batch(%Blocks{} = blocks) do
    transactions_by_block_number =
      Enum.group_by(blocks.transactions_params, & &1.block_number)

    block_structs =
      Enum.map(blocks.blocks_params, fn block ->
        related_transactions =
          Map.get(transactions_by_block_number, block.number, [])
          |> Enum.map(&transaction_from_params/1)

        block_from_params(block, related_transactions, blocks.withdrawals_params)
      end)

    %BlockBatch{
      blocks: block_structs,
      transactions: Enum.map(blocks.transactions_params, &transaction_from_params/1),
      second_degree_relations: blocks.block_second_degree_relations_params,
      withdrawals: blocks.withdrawals_params,
      errors: blocks.errors,
      raw: %{
        blocks_params: blocks.blocks_params,
        transactions_params: blocks.transactions_params,
        block_second_degree_relations_params: blocks.block_second_degree_relations_params,
        withdrawals_params: blocks.withdrawals_params
      }
    }
  end

  defp block_from_params(block, transactions, withdrawals) do
    %Explorer.ChainData.Block{
      hash: block.hash,
      number: block.number,
      parent_hash: block.parent_hash,
      timestamp: block.timestamp,
      miner_hash: Map.get(block, :miner_hash),
      gas_limit: block.gas_limit,
      gas_used: block.gas_used,
      size: block.size,
      nonce: block.nonce,
      difficulty: block.difficulty,
      total_difficulty: Map.get(block, :total_difficulty),
      base_fee_per_gas: Map.get(block, :base_fee_per_gas),
      transactions: transactions,
      uncles: Map.get(block, :uncles, []),
      withdrawals: Enum.filter(withdrawals, &(&1.block_hash == block.hash)),
      raw: block
    }
  end

  defp transaction_from_params(params, raw \\ nil) do
    %Explorer.ChainData.Transaction{
      hash: params.hash,
      block_hash: params.block_hash,
      block_number: params.block_number,
      index: Map.get(params, :index),
      from_address_hash: params.from_address_hash,
      to_address_hash: Map.get(params, :to_address_hash),
      created_contract_address_hash: Map.get(params, :created_contract_address_hash),
      value: params.value,
      gas: params.gas,
      gas_price: params.gas_price,
      max_fee_per_gas: Map.get(params, :max_fee_per_gas),
      max_priority_fee_per_gas: Map.get(params, :max_priority_fee_per_gas),
      input: params.input,
      nonce: params.nonce,
      type: Map.get(params, :type),
      status: Map.get(params, :status),
      raw: raw || params
    }
  end

  defp receipt_from_params(params, logs) do
    transaction_logs =
      logs
      |> Enum.filter(&(&1.transaction_hash == params.transaction_hash))
      |> Enum.map(&log_from_params/1)

    %Explorer.ChainData.Receipt{
      transaction_hash: params.transaction_hash,
      transaction_index: params.transaction_index,
      block_hash: Map.get(params, :block_hash),
      block_number: Map.get(params, :block_number),
      cumulative_gas_used: params.cumulative_gas_used,
      gas_used: params.gas_used,
      gas_price: Map.get(params, :gas_price),
      created_contract_address_hash: Map.get(params, :created_contract_address_hash),
      status: params.status,
      logs_bloom: Map.get(params, :logs_bloom),
      logs: transaction_logs,
      raw: params
    }
  end

  defp log_from_params(params) do
    %Explorer.ChainData.Log{
      address_hash: params.address_hash,
      topics: params.topics,
      data: params.data,
      block_hash: Map.get(params, :block_hash),
      block_number: Map.get(params, :block_number),
      transaction_hash: params.transaction_hash,
      transaction_index: Map.get(params, :transaction_index),
      index: Map.get(params, :index),
      raw: params
    }
  end

  defp balance_from_params(params) do
    %Balance{
      address_hash: params.address_hash,
      block_number: params.block_number,
      value: params.value
    }
  end

  defp nonce_from_params(params) do
    %Nonce{
      address_hash: params.address,
      block_number: params.block_number,
      value: params.nonce
    }
  end

  defp code_from_params(params) do
    %Code{
      address_hash: params.address,
      block_number: params.block_number,
      value: params.code
    }
  end

  defp query_to_rpc_params(%Log.Query{block_hash: block_hash, address: address, topics: topics})
       when is_binary(block_hash) do
    %{block_hash: block_hash}
    |> maybe_put(:address, address)
    |> maybe_put(:topics, topics)
  end

  defp query_to_rpc_params(%Log.Query{} = query) do
    %{
      from_block: quantity_or_tag(query.from_block || "latest"),
      to_block: quantity_or_tag(query.to_block || "latest")
    }
    |> maybe_put(:address, query.address)
    |> maybe_put(:topics, query.topics)
  end

  defp process_receipt_hash_responses(raw_responses, hashes) do
    responses = EthereumJSONRPC.sanitize_responses(raw_responses, Enum.to_list(0..(length(hashes) - 1)))

    case Enum.find(responses, &match?(%{error: _}, &1)) do
      nil -> {:ok, responses}
      %{error: error} -> {:error, error}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_from(map, nil), do: map
  defp maybe_put_from(map, from), do: Map.put(map, :from, from)

  defp quantity_or_tag(number) when is_integer(number), do: integer_to_quantity(number)
  defp quantity_or_tag(tag) when is_binary(tag), do: tag

  defp to_tag(:latest), do: "latest"
  defp to_tag(:safe), do: "safe"
  defp to_tag(:pending), do: "pending"
  defp to_tag(:earliest), do: "earliest"

  defp json_rpc_named_arguments(opts) do
    Keyword.get(opts, :json_rpc_named_arguments) || Application.get_env(:explorer, :json_rpc_named_arguments)
  end
end

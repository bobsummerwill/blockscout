defmodule Explorer.ChainData.STRATO.Mapper do
  @moduledoc false

  alias Explorer.ChainData.{
    Balance,
    Block,
    BlockBatch,
    Code,
    Log,
    Nonce,
    Receipt,
    Transaction
  }

  @spec chain_info(map() | nil) :: {:ok, map()} | {:error, term()}
  def chain_info(nil), do: {:error, :missing_chain_info}

  def chain_info(payload) when is_map(payload) do
    {:ok,
     %{
       chain_id: parse_integer(field(payload, ["chain_id", "chainId"])) || 0,
       head: parse_integer(field(payload, ["head", "head_block_number", "headBlockNumber"])),
       safe_head: parse_integer(field(payload, ["safe_head", "safeHead", "safe_block_number", "safeBlockNumber"]))
     }}
  end

  @spec block(map() | nil) :: Block.t() | nil
  def block(nil), do: nil
  def block(payload) when is_map(payload), do: to_block(payload)

  @spec block_batch(map() | list() | nil) :: BlockBatch.t()
  def block_batch(nil), do: %BlockBatch{}

  def block_batch(payload) when is_list(payload) do
    block_batch(%{"blocks" => payload})
  end

  def block_batch(payload) when is_map(payload) do
    explicit_transactions =
      payload
      |> field(["transactions"])
      |> list_of_maps()
      |> Enum.map(&to_transaction/1)

    blocks =
      payload
      |> field(["blocks"])
      |> list_of_maps()
      |> Enum.map(&to_block/1)

    transactions =
      if explicit_transactions == [] do
        blocks
        |> Enum.flat_map(& &1.transactions)
      else
        explicit_transactions
      end

    %BlockBatch{
      blocks: blocks,
      transactions: transactions,
      second_degree_relations: field(payload, ["second_degree_relations", "secondDegreeRelations"]) || [],
      withdrawals: field(payload, ["withdrawals"]) || [],
      errors: field(payload, ["errors"]) || [],
      raw: payload
    }
  end

  @spec transactions(map() | list() | nil) :: {:ok, [Transaction.t() | nil], [term()]}
  def transactions(nil), do: {:ok, [], []}

  def transactions(payload) when is_list(payload) do
    transactions(%{"transactions" => payload})
  end

  def transactions(payload) when is_map(payload) do
    transactions =
      payload
      |> field(["transactions"])
      |> List.wrap()
      |> Enum.map(fn
        nil -> nil
        tx when is_map(tx) -> to_transaction(tx)
      end)

    {:ok, transactions, field(payload, ["errors"]) || []}
  end

  @spec transactions_count(map() | nil) ::
          {:ok, %{transactions_count_map: %{integer() => integer()}, errors: [term()]}}
  def transactions_count(nil), do: {:ok, %{transactions_count_map: %{}, errors: []}}

  def transactions_count(payload) when is_map(payload) do
    count_map =
      payload
      |> field(["transactions_count_map", "transactionsCountMap"])
      |> normalize_count_map()

    {:ok, %{transactions_count_map: count_map, errors: field(payload, ["errors"]) || []}}
  end

  @spec receipt_batch(map() | list() | nil) :: Receipt.Batch.t()
  def receipt_batch(nil), do: %Receipt.Batch{}

  def receipt_batch(payload) when is_list(payload) do
    receipt_batch(%{"receipts" => payload})
  end

  def receipt_batch(payload) when is_map(payload) do
    logs =
      payload
      |> field(["logs"])
      |> list_of_maps()
      |> Enum.map(&to_log/1)

    receipts =
      payload
      |> field(["receipts"])
      |> list_of_maps()
      |> Enum.map(&to_receipt(&1, logs))

    %Receipt.Batch{
      receipts: receipts,
      logs: logs,
      errors: field(payload, ["errors"]) || [],
      raw: payload
    }
  end

  @spec logs(map() | list() | nil) :: {:ok, [Log.t()]}
  def logs(nil), do: {:ok, []}

  def logs(payload) when is_list(payload) do
    {:ok, Enum.map(payload, &to_log/1)}
  end

  def logs(payload) when is_map(payload) do
    {:ok,
     payload
     |> field(["logs"])
     |> list_of_maps()
     |> Enum.map(&to_log/1)}
  end

  @spec balance_batch(map() | nil) :: Balance.Batch.t()
  def balance_batch(payload), do: to_state_batch(payload, "balances", &to_balance/1, %Balance.Batch{}, :balances)

  @spec nonce_batch(map() | nil) :: Nonce.Batch.t()
  def nonce_batch(payload), do: to_state_batch(payload, "nonces", &to_nonce/1, %Nonce.Batch{}, :nonces)

  @spec code_batch(map() | nil) :: Code.Batch.t()
  def code_batch(payload), do: to_state_batch(payload, "codes", &to_code/1, %Code.Batch{}, :codes)

  defp to_state_batch(nil, _key, _mapper, empty_batch, _field_name), do: empty_batch

  defp to_state_batch(payload, key, mapper, empty_batch, field_name) when is_map(payload) do
    values =
      payload
      |> field([key])
      |> list_of_maps()
      |> Enum.map(mapper)

    Map.merge(empty_batch, %{field_name => values, errors: field(payload, ["errors"]) || []})
  end

  defp to_block(payload) do
    nested_transactions =
      payload
      |> field(["transactions"])
      |> list_of_maps()
      |> Enum.map(&to_transaction/1)

    %Block{
      hash: field(payload, ["hash", "block_hash", "blockHash"]),
      number: parse_integer(field(payload, ["number", "block_number", "blockNumber"])),
      parent_hash: field(payload, ["parent_hash", "parentHash"]),
      timestamp: parse_datetime(field(payload, ["timestamp", "block_timestamp", "blockTimestamp"])),
      miner_hash: field(payload, ["miner_hash", "minerHash", "beneficiary_hash", "beneficiaryHash"]),
      gas_limit: parse_integer(field(payload, ["gas_limit", "gasLimit"])),
      gas_used: parse_integer(field(payload, ["gas_used", "gasUsed"])),
      size: parse_integer(field(payload, ["size"])),
      nonce: parse_integer(field(payload, ["nonce"])),
      difficulty: parse_integer(field(payload, ["difficulty"])),
      total_difficulty: parse_integer(field(payload, ["total_difficulty", "totalDifficulty"])),
      base_fee_per_gas: parse_integer(field(payload, ["base_fee_per_gas", "baseFeePerGas"])),
      transactions: nested_transactions,
      uncles: field(payload, ["uncles"]) || [],
      withdrawals: field(payload, ["withdrawals"]) || [],
      raw: payload
    }
  end

  defp to_transaction(payload) do
    %Transaction{
      hash: field(payload, ["hash", "transaction_hash", "transactionHash"]),
      block_hash: field(payload, ["block_hash", "blockHash"]),
      block_number: parse_integer(field(payload, ["block_number", "blockNumber"])),
      index: parse_integer(field(payload, ["index", "transaction_index", "transactionIndex"])),
      from_address_hash: field(payload, ["from_address_hash", "from", "fromAddressHash"]),
      to_address_hash: field(payload, ["to_address_hash", "to", "toAddressHash"]),
      created_contract_address_hash:
        field(payload, [
          "created_contract_address_hash",
          "createdContractAddressHash",
          "contract_address",
          "contractAddress"
        ]),
      value: parse_integer(field(payload, ["value"])),
      gas: parse_integer(field(payload, ["gas"])),
      gas_price: parse_integer(field(payload, ["gas_price", "gasPrice"])),
      max_fee_per_gas: parse_integer(field(payload, ["max_fee_per_gas", "maxFeePerGas"])),
      max_priority_fee_per_gas:
        parse_integer(field(payload, ["max_priority_fee_per_gas", "maxPriorityFeePerGas"])),
      input: field(payload, ["input", "data"]),
      nonce: parse_integer(field(payload, ["nonce"])),
      type: parse_integer(field(payload, ["type"])),
      status: parse_status(field(payload, ["status"])),
      raw: payload
    }
  end

  defp to_receipt(payload, logs) do
    transaction_hash = field(payload, ["transaction_hash", "transactionHash"])

    related_logs =
      Enum.filter(logs, &(&1.transaction_hash == transaction_hash))

    %Receipt{
      transaction_hash: transaction_hash,
      transaction_index: parse_integer(field(payload, ["transaction_index", "transactionIndex"])),
      block_hash: field(payload, ["block_hash", "blockHash"]),
      block_number: parse_integer(field(payload, ["block_number", "blockNumber"])),
      cumulative_gas_used: parse_integer(field(payload, ["cumulative_gas_used", "cumulativeGasUsed"])),
      gas_used: parse_integer(field(payload, ["gas_used", "gasUsed"])),
      gas_price: parse_integer(field(payload, ["gas_price", "gasPrice"])),
      created_contract_address_hash:
        field(payload, ["created_contract_address_hash", "createdContractAddressHash", "contract_address", "contractAddress"]),
      status: parse_status(field(payload, ["status"])),
      logs_bloom: field(payload, ["logs_bloom", "logsBloom"]),
      logs: related_logs,
      raw: payload
    }
  end

  defp to_log(payload) do
    %Log{
      address_hash: field(payload, ["address_hash", "address"]),
      topics: field(payload, ["topics"]) || [],
      data: field(payload, ["data"]),
      block_hash: field(payload, ["block_hash", "blockHash"]),
      block_number: parse_integer(field(payload, ["block_number", "blockNumber"])),
      transaction_hash: field(payload, ["transaction_hash", "transactionHash"]),
      transaction_index: parse_integer(field(payload, ["transaction_index", "transactionIndex"])),
      index: parse_integer(field(payload, ["index", "log_index", "logIndex"])),
      raw: payload
    }
  end

  defp to_balance(payload) do
    %Balance{
      address_hash: field(payload, ["address_hash", "address", "addressHash"]),
      block_number: parse_integer(field(payload, ["block_number", "blockNumber"])),
      value: parse_integer(field(payload, ["value", "balance"]))
    }
  end

  defp to_nonce(payload) do
    %Nonce{
      address_hash: field(payload, ["address_hash", "address", "addressHash"]),
      block_number: parse_integer(field(payload, ["block_number", "blockNumber"])),
      value: parse_integer(field(payload, ["value", "nonce"]))
    }
  end

  defp to_code(payload) do
    %Code{
      address_hash: field(payload, ["address_hash", "address", "addressHash"]),
      block_number: parse_integer(field(payload, ["block_number", "blockNumber"])),
      value: field(payload, ["value", "code"]) || "0x"
    }
  end

  defp field(nil, _keys), do: nil

  defp field(payload, keys) when is_map(payload) do
    Enum.find_value(keys, fn key ->
      Map.get(payload, key) || Map.get(payload, maybe_existing_atom(key))
    end)
  end

  defp maybe_existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp maybe_existing_atom(key), do: key

  defp list_of_maps(nil), do: []
  defp list_of_maps(list) when is_list(list), do: Enum.filter(list, &is_map/1)
  defp list_of_maps(_other), do: []

  defp normalize_count_map(nil), do: %{}

  defp normalize_count_map(counts) when is_map(counts) do
    Map.new(counts, fn {key, value} -> {parse_integer(key), parse_integer(value)} end)
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_float(value), do: trunc(value)

  defp parse_integer("0x" <> _rest = value) do
    EthereumJSONRPC.quantity_to_integer(value)
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp parse_integer(_value), do: nil

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = value), do: value

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(value) when is_integer(value) do
    DateTime.from_unix!(value)
  rescue
    _ -> nil
  end

  defp parse_datetime(_value), do: nil

  defp parse_status(value) when value in [1, "1", "0x1", true, :ok, "ok", "success", "succeeded"], do: :ok
  defp parse_status(value) when value in [0, "0", "0x0", false, :error, "error", "failed", "failure"], do: :error
  defp parse_status(_value), do: nil
end

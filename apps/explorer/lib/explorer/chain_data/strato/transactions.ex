defmodule Explorer.ChainData.STRATO.Transactions do
  @moduledoc false

  alias Explorer.ChainData.InternalTransaction
  alias Explorer.ChainData.STRATO.{Blocks, Client, Config, Mapper}

  @spec by_hashes([EthereumJSONRPC.hash()], keyword()) ::
          {:ok, [Explorer.ChainData.Transaction.t() | nil], [term()]} | {:error, term()}
  def by_hashes(hashes, opts) do
    config = Config.get(opts)

    case Config.profile(config) do
      :core_api ->
        fetch_transactions_from_core_api(hashes, opts, config)

      :private_explorer_api ->
        with {:ok, payload} <- Client.post(Config.endpoint(:transactions_by_hashes, config), %{hashes: hashes}, opts) do
          Mapper.transactions(payload)
        end
    end
  end

  @spec counts_by_block_numbers([EthereumJSONRPC.block_number()], keyword()) ::
          {:ok, %{transactions_count_map: %{integer() => integer()}, errors: [term()]}} | {:error, term()}
  def counts_by_block_numbers(block_numbers, opts) do
    config = Config.get(opts)

    case Config.profile(config) do
      :core_api ->
        with {:ok, block_batch} <- Blocks.blocks_by_numbers(block_numbers, true, opts) do
          count_map =
            Map.new(block_batch.blocks, fn block ->
              {block.number, length(block.transactions)}
            end)

          {:ok, %{transactions_count_map: count_map, errors: []}}
        end

      :private_explorer_api ->
        with {:ok, payload} <-
               Client.post(
                 Config.endpoint(:transactions_count_by_block_numbers, config),
                 %{block_numbers: block_numbers},
                 opts
               ) do
          Mapper.transactions_count(payload)
        end
    end
  end

  @spec first_trace([map()], keyword()) :: {:ok, [map()]} | {:error, term()} | :ignore
  def first_trace(transactions, opts) do
    config = Config.get(opts)

    case Config.profile(config) do
      :core_api ->
        :ignore

      :private_explorer_api ->
        with {:ok, payload} <- Client.post(Config.endpoint(:transactions_first_trace, config), transactions, opts) do
          parse_first_trace(payload)
        end
    end
  end

  @spec raw_traces_by_transaction(%{hash: EthereumJSONRPC.hash(), block_number: EthereumJSONRPC.block_number()}, keyword()) ::
          {:ok, [map()]} | {:error, term()} | :ignore
  def raw_traces_by_transaction(%{hash: hash}, opts) do
    config = Config.get(opts)

    case Config.profile(config) do
      :core_api ->
        :ignore

      :private_explorer_api ->
        with {:ok, payload} <-
               Client.post(
                 Config.endpoint(:transactions_raw_traces, config),
                 %{hash: hash},
                 opts
               ) do
          parse_raw_traces(payload)
        end
    end
  end

  @spec internal_transactions_by_block_numbers([EthereumJSONRPC.block_number()], keyword()) ::
          {:ok, [InternalTransaction.t()]} | {:error, term()} | :ignore
  def internal_transactions_by_block_numbers(_block_numbers, _opts), do: :ignore

  @spec internal_transactions_by_transactions([map()], keyword()) ::
          {:ok, [InternalTransaction.t()]} | {:error, term()} | :ignore
  def internal_transactions_by_transactions(_transactions, _opts), do: :ignore

  defp fetch_transactions_from_core_api(hashes, opts, config) do
    hashes
    |> Enum.reduce_while({:ok, []}, fn hash, {:ok, transactions} ->
      case Client.get(Config.endpoint(:transactions_query, config), Keyword.put(opts, :params, [hash: hash])) do
        {:ok, payload} ->
          case Mapper.transactions(payload) do
            {:ok, [transaction | _], _errors} ->
              {:cont, {:ok, [transaction | transactions]}}

            {:ok, [], _errors} ->
              {:cont, {:ok, [nil | transactions]}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, transactions} -> {:ok, Enum.reverse(transactions), []}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_first_trace(%{"items" => items}) when is_list(items) do
    {:ok, Enum.map(items, &normalize_first_trace_item/1)}
  end

  defp parse_first_trace(%{"errors" => [_ | _] = errors}) do
    {:error, errors}
  end

  defp parse_first_trace(other), do: {:error, {:unexpected_first_trace_payload, other}}

  defp parse_raw_traces(%{"traces" => traces}) when is_list(traces), do: {:ok, traces}
  defp parse_raw_traces(%{"errors" => [_ | _] = errors}), do: {:error, errors}
  defp parse_raw_traces(other), do: {:error, {:unexpected_raw_traces_payload, other}}

  defp parse_internal_transactions(%{"internal_transactions" => items}) when is_list(items) do
    {:ok, Enum.map(items, &%InternalTransaction{params: normalize_internal_transaction(&1)})}
  end

  defp parse_internal_transactions(%{"errors" => [_ | _] = errors}) do
    {:error, errors}
  end

  defp parse_internal_transactions(other), do: {:error, {:unexpected_internal_transactions_payload, other}}

  defp normalize_first_trace_item(%{"first_trace" => first_trace} = item) do
    %{
      block_hash: item["block_hash"],
      block_number: item["block_number"],
      first_trace: normalize_first_trace(first_trace)
    }
  end

  defp normalize_first_trace_item(item), do: item

  defp normalize_first_trace(first_trace) do
    output = normalized_output(first_trace["output"], first_trace["error"])

    %{}
    |> maybe_put(:transaction_hash, first_trace["transaction_hash"])
    |> maybe_put(:call_type, first_trace["call_type"])
    |> maybe_put(:created_contract_address_hash, first_trace["created_contract_address_hash"])
    |> maybe_put(:created_contract_code, first_trace["created_contract_code"])
    |> maybe_put(:error, first_trace["error"])
    |> maybe_put(:from_address_hash, first_trace["from_address_hash"])
    |> maybe_put(:gas, first_trace["gas"])
    |> maybe_put(:gas_used, first_trace["gas_used"])
    |> maybe_put(:index, first_trace["index"])
    |> maybe_put(:init, first_trace["init"])
    |> maybe_put(:input, first_trace["input"])
    |> maybe_put(:output, output)
    |> maybe_put(:to_address_hash, first_trace["to_address_hash"])
    |> maybe_put(:trace_address, first_trace["trace_address"])
    |> maybe_put(:transaction_index, first_trace["transaction_index"])
    |> maybe_put(:type, first_trace["type"])
    |> maybe_put(:value, first_trace["value"])
  end

  defp normalize_internal_transaction(item) do
    output = normalized_output(item["output"], item["error"])

    %{}
    |> maybe_put(:block_hash, item["block_hash"])
    |> maybe_put(:block_number, item["block_number"])
    |> maybe_put(:call_type, item["call_type"])
    |> maybe_put(:created_contract_address_hash, item["created_contract_address_hash"])
    |> maybe_put(:created_contract_code, item["created_contract_code"])
    |> maybe_put(:error, item["error"])
    |> maybe_put(:from_address_hash, item["from_address_hash"])
    |> maybe_put(:gas, item["gas"])
    |> maybe_put(:gas_used, item["gas_used"])
    |> maybe_put(:index, item["index"])
    |> maybe_put(:init, item["init"])
    |> maybe_put(:input, item["input"])
    |> maybe_put(:output, output)
    |> maybe_put(:to_address_hash, item["to_address_hash"])
    |> maybe_put(:trace_address, item["trace_address"])
    |> maybe_put(:transaction_hash, item["transaction_hash"])
    |> maybe_put(:transaction_index, item["transaction_index"])
    |> maybe_put(:type, item["type"])
    |> maybe_put(:value, normalize_value(item["value"]))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp normalize_value(nil), do: nil
  defp normalize_value(0), do: nil
  defp normalize_value("0"), do: nil
  defp normalize_value(value), do: value

  defp normalized_output(nil, nil), do: "0x"
  defp normalized_output(nil, _error), do: nil
  defp normalized_output("", nil), do: "0x"
  defp normalized_output("", _error), do: nil
  defp normalized_output(value, _error), do: value
end

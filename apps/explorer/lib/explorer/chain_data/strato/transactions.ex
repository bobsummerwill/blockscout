defmodule Explorer.ChainData.STRATO.Transactions do
  @moduledoc false

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
end

defmodule Explorer.ChainData.STRATO.Blocks do
  @moduledoc false

  alias Explorer.ChainData.BlockBatch
  alias Explorer.ChainData.STRATO.{Client, Config, Mapper}

  @spec chain_info(keyword()) :: {:ok, map()} | {:error, term()}
  def chain_info(opts) do
    config = Config.get(opts)

    case Config.profile(config) do
      :core_api ->
        with {:ok, metadata} <- Client.get(Config.endpoint(:chain_info, config), opts),
             {:ok, %BlockBatch{blocks: [%{number: head} | _]}} <-
               fetch_last_blocks(1, opts, config) do
          metadata
          |> Map.put("head", head)
          |> Mapper.chain_info()
        end

      :private_explorer_api ->
        with {:ok, payload} <- Client.get(Config.endpoint(:chain_info, config), opts) do
          Mapper.chain_info(payload)
        end
    end
  end

  @spec block_by_tag(atom(), keyword()) :: {:ok, Explorer.ChainData.Block.t() | nil} | {:error, term()}
  def block_by_tag(tag, opts) do
    config = Config.get(opts)

    case Config.profile(config) do
      :core_api ->
        core_api_block_by_tag(tag, opts, config)

      :private_explorer_api ->
        path = Path.join(Config.endpoint(:block_by_tag, config), Atom.to_string(tag))

        with {:ok, payload} <- Client.get(path, Keyword.put(opts, :params, [hydrated: true])) do
          {:ok, Mapper.block(payload)}
        end
    end
  end

  @spec blocks_by_range(Range.t(), boolean(), keyword()) ::
          {:ok, Explorer.ChainData.BlockBatch.t()} | {:error, term()}
  def blocks_by_range(first..last//_step, hydrated?, opts) do
    config = Config.get(opts)

    case Config.profile(config) do
      :core_api ->
        with {:ok, payload} <-
               Client.get(
                 Config.endpoint(:blocks_query, config),
                 Keyword.put(opts, :params, [minnumber: first, maxnumber: last])
               ) do
          {:ok, Mapper.block_batch(payload)}
        end

      :private_explorer_api ->
        request_body = %{from: first, to: last, hydrated: hydrated?}

        with {:ok, payload} <- request(:blocks_by_range, request_body, opts) do
          {:ok, Mapper.block_batch(payload)}
        end
    end
  end

  @spec blocks_by_numbers([EthereumJSONRPC.block_number()], boolean(), keyword()) ::
          {:ok, Explorer.ChainData.BlockBatch.t()} | {:error, term()}
  def blocks_by_numbers(block_numbers, hydrated?, opts) do
    config = Config.get(opts)

    case Config.profile(config) do
      :core_api ->
        fetch_block_batch(block_numbers, hydrated?, opts, fn block_number ->
          Client.get(Config.endpoint(:blocks_query, config), Keyword.put(opts, :params, [number: block_number]))
        end)

      :private_explorer_api ->
        request_body = %{block_numbers: block_numbers, hydrated: hydrated?}

        with {:ok, payload} <- request(:blocks_by_numbers, request_body, opts) do
          {:ok, Mapper.block_batch(payload)}
        end
    end
  end

  @spec blocks_by_hashes([EthereumJSONRPC.hash()], boolean(), keyword()) ::
          {:ok, Explorer.ChainData.BlockBatch.t()} | {:error, term()}
  def blocks_by_hashes(hashes, hydrated?, opts) do
    config = Config.get(opts)

    case Config.profile(config) do
      :core_api ->
        fetch_block_batch(hashes, hydrated?, opts, fn hash ->
          Client.get(Config.endpoint(:blocks_query, config), Keyword.put(opts, :params, [hash: hash]))
        end)

      :private_explorer_api ->
        request_body = %{hashes: hashes, hydrated: hydrated?}

        with {:ok, payload} <- request(:blocks_by_hashes, request_body, opts) do
          {:ok, Mapper.block_batch(payload)}
        end
    end
  end

  defp request(endpoint, body, opts) do
    config = Config.get(opts)
    Client.post(Config.endpoint(endpoint, config), body, opts)
  end

  defp core_api_block_by_tag(:latest, opts, config) do
    with {:ok, %BlockBatch{blocks: [block | _]}} <- fetch_last_blocks(1, opts, config) do
      {:ok, block}
    end
  end

  defp core_api_block_by_tag(tag, _opts, _config), do: {:error, {:unsupported_block_tag, tag}}

  defp fetch_last_blocks(count, opts, config) do
    path = Path.join(Config.endpoint(:block_last, config), Integer.to_string(count))

    with {:ok, payload} <- Client.get(path, opts) do
      {:ok, Mapper.block_batch(payload)}
    end
  end

  defp fetch_block_batch(items, _hydrated?, _opts, fetcher) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, batches} ->
      case fetcher.(item) do
        {:ok, payload} ->
          {:cont, {:ok, [Mapper.block_batch(payload) | batches]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> merge_batches()
  end

  defp merge_batches({:error, reason}), do: {:error, reason}

  defp merge_batches({:ok, batches}) do
    merged =
      Enum.reduce(Enum.reverse(batches), %BlockBatch{}, fn batch, acc ->
        %BlockBatch{
          blocks: acc.blocks ++ batch.blocks,
          transactions: acc.transactions ++ batch.transactions,
          second_degree_relations: acc.second_degree_relations ++ batch.second_degree_relations,
          withdrawals: acc.withdrawals ++ batch.withdrawals,
          errors: acc.errors ++ batch.errors,
          raw: [batch.raw | List.wrap(acc.raw)]
        }
      end)

    {:ok, merged}
  end
end

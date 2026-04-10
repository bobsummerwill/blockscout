defmodule Explorer.ChainData.STRATO.Blocks do
  @moduledoc false

  alias Explorer.ChainData.STRATO.{Client, Config, Mapper}

  @spec chain_info(keyword()) :: {:ok, map()} | {:error, term()}
  def chain_info(opts) do
    config = Config.get(opts)

    with {:ok, payload} <- Client.get(Config.endpoint(:chain_info, config), opts) do
      Mapper.chain_info(payload)
    end
  end

  @spec block_by_tag(atom(), keyword()) :: {:ok, Explorer.ChainData.Block.t() | nil} | {:error, term()}
  def block_by_tag(tag, opts) do
    config = Config.get(opts)
    path = Path.join(Config.endpoint(:block_by_tag, config), Atom.to_string(tag))

    with {:ok, payload} <- Client.get(path, Keyword.put(opts, :params, [hydrated: true])) do
      {:ok, Mapper.block(payload)}
    end
  end

  @spec blocks_by_range(Range.t(), boolean(), keyword()) ::
          {:ok, Explorer.ChainData.BlockBatch.t()} | {:error, term()}
  def blocks_by_range(first..last//_step, hydrated?, opts) do
    request_body = %{from: first, to: last, hydrated: hydrated?}

    with {:ok, payload} <- request(:blocks_by_range, request_body, opts) do
      {:ok, Mapper.block_batch(payload)}
    end
  end

  @spec blocks_by_numbers([EthereumJSONRPC.block_number()], boolean(), keyword()) ::
          {:ok, Explorer.ChainData.BlockBatch.t()} | {:error, term()}
  def blocks_by_numbers(block_numbers, hydrated?, opts) do
    request_body = %{block_numbers: block_numbers, hydrated: hydrated?}

    with {:ok, payload} <- request(:blocks_by_numbers, request_body, opts) do
      {:ok, Mapper.block_batch(payload)}
    end
  end

  @spec blocks_by_hashes([EthereumJSONRPC.hash()], boolean(), keyword()) ::
          {:ok, Explorer.ChainData.BlockBatch.t()} | {:error, term()}
  def blocks_by_hashes(hashes, hydrated?, opts) do
    request_body = %{hashes: hashes, hydrated: hydrated?}

    with {:ok, payload} <- request(:blocks_by_hashes, request_body, opts) do
      {:ok, Mapper.block_batch(payload)}
    end
  end

  defp request(endpoint, body, opts) do
    config = Config.get(opts)
    Client.post(Config.endpoint(endpoint, config), body, opts)
  end
end

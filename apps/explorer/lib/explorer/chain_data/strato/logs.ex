defmodule Explorer.ChainData.STRATO.Logs do
  @moduledoc false

  alias Explorer.ChainData.Log.Query
  alias Explorer.ChainData.STRATO.{Client, Config, Mapper}

  @spec search(Query.t(), keyword()) :: {:ok, [Explorer.ChainData.Log.t()]} | {:error, term()}
  def search(%Query{} = query, opts) do
    config = Config.get(opts)

    with {:ok, payload} <- Client.post(Config.endpoint(:logs_search, config), query_to_body(query), opts) do
      Mapper.logs(payload)
    end
  end

  defp query_to_body(%Query{} = query) do
    %{}
    |> maybe_put(:from_block, query.from_block)
    |> maybe_put(:to_block, query.to_block)
    |> maybe_put(:block_hash, query.block_hash)
    |> maybe_put(:address, query.address)
    |> maybe_put(:topics, query.topics)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

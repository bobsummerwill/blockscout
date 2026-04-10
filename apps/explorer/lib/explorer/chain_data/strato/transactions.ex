defmodule Explorer.ChainData.STRATO.Transactions do
  @moduledoc false

  alias Explorer.ChainData.STRATO.{Client, Config, Mapper}

  @spec by_hashes([EthereumJSONRPC.hash()], keyword()) ::
          {:ok, [Explorer.ChainData.Transaction.t() | nil], [term()]} | {:error, term()}
  def by_hashes(hashes, opts) do
    config = Config.get(opts)

    with {:ok, payload} <- Client.post(Config.endpoint(:transactions_by_hashes, config), %{hashes: hashes}, opts) do
      Mapper.transactions(payload)
    end
  end

  @spec counts_by_block_numbers([EthereumJSONRPC.block_number()], keyword()) ::
          {:ok, %{transactions_count_map: %{integer() => integer()}, errors: [term()]}} | {:error, term()}
  def counts_by_block_numbers(block_numbers, opts) do
    config = Config.get(opts)

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

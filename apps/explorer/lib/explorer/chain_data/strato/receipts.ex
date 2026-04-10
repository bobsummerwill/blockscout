defmodule Explorer.ChainData.STRATO.Receipts do
  @moduledoc false

  alias Explorer.ChainData.STRATO.{Client, Config, Mapper}

  @spec by_block_numbers([EthereumJSONRPC.block_number()], keyword()) ::
          {:ok, Explorer.ChainData.Receipt.Batch.t()} | {:error, term()}
  def by_block_numbers(block_numbers, opts) do
    config = Config.get(opts)

    with {:ok, payload} <-
           Client.post(Config.endpoint(:receipts_by_block_numbers, config), %{block_numbers: block_numbers}, opts) do
      {:ok, Mapper.receipt_batch(payload)}
    end
  end

  @spec by_transaction_hashes([EthereumJSONRPC.hash()], keyword()) ::
          {:ok, Explorer.ChainData.Receipt.Batch.t()} | {:error, term()}
  def by_transaction_hashes(hashes, opts) do
    config = Config.get(opts)

    with {:ok, payload} <-
           Client.post(Config.endpoint(:receipts_by_transaction_hashes, config), %{hashes: hashes}, opts) do
      {:ok, Mapper.receipt_batch(payload)}
    end
  end
end

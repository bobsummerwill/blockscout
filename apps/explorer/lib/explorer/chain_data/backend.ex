defmodule Explorer.ChainData.Backend do
  @moduledoc """
  Dispatches chain data requests to the configured backend implementation.
  """

  alias Explorer.ChainData

  @spec impl() :: module()
  def impl do
    Application.get_env(:explorer, ChainData, [])
    |> Keyword.get(:backend, Explorer.ChainData.EthereumJSONRPC)
  end

  @spec chain_info(ChainData.opts()) :: {:ok, map()} | {:error, term()}
  def chain_info(opts \\ []) do
    impl().chain_info(opts)
  end

  @spec block_by_tag(:latest | :safe | :pending | :earliest, ChainData.opts()) ::
          {:ok, Explorer.ChainData.Block.t() | nil} | {:error, term()}
  def block_by_tag(tag, opts \\ []) do
    impl().block_by_tag(tag, opts)
  end

  @spec blocks_by_range(Range.t(), boolean(), ChainData.opts()) ::
          {:ok, Explorer.ChainData.BlockBatch.t()} | {:error, term()}
  def blocks_by_range(range, hydrated? \\ true, opts \\ []) do
    impl().blocks_by_range(range, hydrated?, opts)
  end

  @spec blocks_by_numbers([EthereumJSONRPC.block_number()], boolean(), ChainData.opts()) ::
          {:ok, Explorer.ChainData.BlockBatch.t()} | {:error, term()}
  def blocks_by_numbers(block_numbers, hydrated? \\ true, opts \\ []) do
    impl().blocks_by_numbers(block_numbers, hydrated?, opts)
  end

  @spec blocks_by_hashes([EthereumJSONRPC.hash()], boolean(), ChainData.opts()) ::
          {:ok, Explorer.ChainData.BlockBatch.t()} | {:error, term()}
  def blocks_by_hashes(hashes, hydrated? \\ true, opts \\ []) do
    impl().blocks_by_hashes(hashes, hydrated?, opts)
  end

  @spec transactions_by_hashes([EthereumJSONRPC.hash()], ChainData.opts()) ::
          {:ok, [Explorer.ChainData.Transaction.t() | nil], [term()]} | {:error, term()}
  def transactions_by_hashes(hashes, opts \\ []) do
    impl().transactions_by_hashes(hashes, opts)
  end

  @spec receipts_by_block_numbers([EthereumJSONRPC.block_number()], ChainData.opts()) ::
          {:ok, Explorer.ChainData.Receipt.Batch.t()} | {:error, term()}
  def receipts_by_block_numbers(block_numbers, opts \\ []) do
    impl().receipts_by_block_numbers(block_numbers, opts)
  end

  @spec receipts_by_transaction_hashes([EthereumJSONRPC.hash()], ChainData.opts()) ::
          {:ok, Explorer.ChainData.Receipt.Batch.t()} | {:error, term()}
  def receipts_by_transaction_hashes(hashes, opts \\ []) do
    impl().receipts_by_transaction_hashes(hashes, opts)
  end

  @spec logs(Explorer.ChainData.Log.Query.t(), ChainData.opts()) ::
          {:ok, [Explorer.ChainData.Log.t()]} | {:error, term()}
  def logs(query, opts \\ []) do
    impl().logs(query, opts)
  end

  @spec balances_at([Explorer.ChainData.Balance.Request.t()], ChainData.opts()) ::
          {:ok, Explorer.ChainData.Balance.Batch.t()} | {:error, term()}
  def balances_at(requests, opts \\ []) do
    impl().balances_at(requests, opts)
  end

  @spec nonces_at([Explorer.ChainData.Nonce.Request.t()], ChainData.opts()) ::
          {:ok, Explorer.ChainData.Nonce.Batch.t()} | {:error, term()}
  def nonces_at(requests, opts \\ []) do
    impl().nonces_at(requests, opts)
  end

  @spec codes_at([Explorer.ChainData.Code.Request.t()], ChainData.opts()) ::
          {:ok, Explorer.ChainData.Code.Batch.t()} | {:error, term()}
  def codes_at(requests, opts \\ []) do
    impl().codes_at(requests, opts)
  end

  @spec contract_calls([Explorer.ChainData.Call.Request.t()], term(), boolean(), ChainData.opts()) ::
          [Explorer.ChainData.Call.Result.t()]
  def contract_calls(requests, abi, leave_error_as_map \\ false, opts \\ []) do
    impl().contract_calls(requests, abi, leave_error_as_map, opts)
  end

  @spec internal_transactions_by_block_numbers([EthereumJSONRPC.block_number()], ChainData.opts()) ::
          {:ok, [Explorer.ChainData.InternalTransaction.t()]} | {:error, term()} | :ignore
  def internal_transactions_by_block_numbers(block_numbers, opts \\ []) do
    impl().internal_transactions_by_block_numbers(block_numbers, opts)
  end

  @spec internal_transactions_by_transactions([map()], ChainData.opts()) ::
          {:ok, [Explorer.ChainData.InternalTransaction.t()]} | {:error, term()} | :ignore
  def internal_transactions_by_transactions(transactions, opts \\ []) do
    impl().internal_transactions_by_transactions(transactions, opts)
  end

  @spec raw_traces_by_transaction(
          %{hash: EthereumJSONRPC.hash(), block_number: EthereumJSONRPC.block_number()},
          ChainData.opts()
        ) ::
          {:ok, [map()]} | {:error, term()} | :ignore
  def raw_traces_by_transaction(transaction, opts \\ []) do
    impl().raw_traces_by_transaction(transaction, opts)
  end

  @spec subscribe_new_blocks(ChainData.opts()) :: {:ok, term()} | {:error, term()} | :ignore
  def subscribe_new_blocks(opts \\ []) do
    impl().subscribe_new_blocks(opts)
  end
end

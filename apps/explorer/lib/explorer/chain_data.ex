defmodule Explorer.ChainData do
  @moduledoc """
  Backend-neutral chain data interface for explorer and indexer reads.

  The existing Ethereum JSON-RPC integration is one implementation of this
  behaviour. Additional chain-native implementations, such as STRATO, can
  satisfy the same contract without exposing an Ethereum-compatible RPC surface.
  """

  alias Explorer.ChainData.{
    Balance,
    Block,
    BlockBatch,
    Call,
    Code,
    InternalTransaction,
    Log,
    Nonce,
    Receipt,
    Transaction
  }

  @type opts :: keyword()

  @callback chain_info(opts()) ::
              {:ok,
               %{
                 chain_id: non_neg_integer(),
                 head: non_neg_integer() | nil,
                 safe_head: non_neg_integer() | nil
               }}
              | {:error, term()}

  @callback block_by_tag(:latest | :safe | :pending | :earliest, opts()) ::
              {:ok, Block.t() | nil} | {:error, term()}

  @callback blocks_by_range(Range.t(), boolean(), opts()) ::
              {:ok, BlockBatch.t()} | {:error, term()}

  @callback blocks_by_hashes([EthereumJSONRPC.hash()], boolean(), opts()) ::
              {:ok, BlockBatch.t()} | {:error, term()}

  @callback transactions_by_hashes([EthereumJSONRPC.hash()], opts()) ::
              {:ok, [Transaction.t() | nil], [term()]} | {:error, term()}

  @callback receipts_by_block_numbers([EthereumJSONRPC.block_number()], opts()) ::
              {:ok, Receipt.Batch.t()} | {:error, term()}

  @callback receipts_by_transaction_hashes([EthereumJSONRPC.hash()], opts()) ::
              {:ok, Receipt.Batch.t()} | {:error, term()}

  @callback logs(Log.Query.t(), opts()) ::
              {:ok, [Log.t()]} | {:error, term()}

  @callback balances_at([Balance.Request.t()], opts()) ::
              {:ok, Balance.Batch.t()} | {:error, term()}

  @callback nonces_at([Nonce.Request.t()], opts()) ::
              {:ok, Nonce.Batch.t()} | {:error, term()}

  @callback codes_at([Code.Request.t()], opts()) ::
              {:ok, Code.Batch.t()} | {:error, term()}

  @callback contract_calls([Call.Request.t()], term(), boolean(), opts()) ::
              [Call.Result.t()]

  @callback internal_transactions_by_block_numbers([EthereumJSONRPC.block_number()], opts()) ::
              {:ok, [InternalTransaction.t()]} | {:error, term()} | :ignore

  @callback internal_transactions_by_transactions([map()], opts()) ::
              {:ok, [InternalTransaction.t()]} | {:error, term()} | :ignore

  @callback raw_traces_by_transaction(
              %{hash: EthereumJSONRPC.hash(), block_number: EthereumJSONRPC.block_number()},
              opts()
            ) ::
              {:ok, [map()]} | {:error, term()} | :ignore

  @callback subscribe_new_blocks(opts()) ::
              {:ok, term()} | {:error, term()} | :ignore
end

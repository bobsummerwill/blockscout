defmodule Explorer.ChainData.STRATO do
  @moduledoc """
  `Explorer.ChainData` implementation backed by STRATO-native APIs.

  Two profiles are supported:

  * `:private_explorer_api` for a Blockscout-oriented aggregated STRATO API.
  * `:core_api` for STRATO's existing `/eth/v1.2` query-style API.

  The private explorer profile covers the fuller read-only slice needed by the
  Blockscout indexer and explorer. The core API profile only maps the subset
  STRATO currently exposes directly, and returns explicit unsupported errors
  for explorer-grade receipts, logs, and contract bytecode reads.
  """

  @behaviour Explorer.ChainData

  alias Explorer.ChainData.STRATO.{
    Blocks,
    Logs,
    Receipts,
    State,
    Transactions
  }

  @impl Explorer.ChainData
  def chain_info(opts), do: Blocks.chain_info(opts)

  @impl Explorer.ChainData
  def block_by_tag(tag, opts), do: Blocks.block_by_tag(tag, opts)

  @impl Explorer.ChainData
  def blocks_by_range(range, hydrated?, opts), do: Blocks.blocks_by_range(range, hydrated?, opts)

  @impl Explorer.ChainData
  def blocks_by_numbers(block_numbers, hydrated?, opts), do: Blocks.blocks_by_numbers(block_numbers, hydrated?, opts)

  @impl Explorer.ChainData
  def blocks_by_hashes(hashes, hydrated?, opts), do: Blocks.blocks_by_hashes(hashes, hydrated?, opts)

  @impl Explorer.ChainData
  def transactions_by_hashes(hashes, opts), do: Transactions.by_hashes(hashes, opts)

  @impl Explorer.ChainData
  def transactions_count_by_block_numbers(block_numbers, opts), do: Transactions.counts_by_block_numbers(block_numbers, opts)

  @impl Explorer.ChainData
  def receipts_by_block_numbers(block_numbers, opts), do: Receipts.by_block_numbers(block_numbers, opts)

  @impl Explorer.ChainData
  def receipts_by_transaction_hashes(hashes, opts), do: Receipts.by_transaction_hashes(hashes, opts)

  @impl Explorer.ChainData
  def logs(query, opts), do: Logs.search(query, opts)

  @impl Explorer.ChainData
  def balances_at(requests, opts), do: State.balances(requests, opts)

  @impl Explorer.ChainData
  def nonces_at(requests, opts), do: State.nonces(requests, opts)

  @impl Explorer.ChainData
  def codes_at(requests, opts), do: State.codes(requests, opts)

  @impl Explorer.ChainData
  def contract_calls(_requests, _abi, _leave_error_as_map, _opts), do: []

  @impl Explorer.ChainData
  def internal_transactions_by_block_numbers(_block_numbers, _opts), do: :ignore

  @impl Explorer.ChainData
  def internal_transactions_by_transactions(_transactions, _opts), do: :ignore

  @impl Explorer.ChainData
  def raw_traces_by_transaction(_transaction, _opts), do: :ignore

  @impl Explorer.ChainData
  def first_trace(_transactions, _opts), do: :ignore

  @impl Explorer.ChainData
  def subscribe_new_blocks(_opts), do: :ignore
end

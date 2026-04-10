defmodule Explorer.ChainData.STRATO do
  @moduledoc """
  Placeholder `Explorer.ChainData` implementation for a future STRATO-native
  backend.

  The first PR only introduces the backend seam. A later change will implement
  these callbacks against STRATO APIs and indexed data sources.
  """

  @behaviour Explorer.ChainData

  @not_implemented {:error, :not_implemented}

  @impl Explorer.ChainData
  def chain_info(_opts), do: @not_implemented

  @impl Explorer.ChainData
  def block_by_tag(_tag, _opts), do: @not_implemented

  @impl Explorer.ChainData
  def blocks_by_range(_range, _hydrated?, _opts), do: @not_implemented

  @impl Explorer.ChainData
  def blocks_by_numbers(_block_numbers, _hydrated?, _opts), do: @not_implemented

  @impl Explorer.ChainData
  def blocks_by_hashes(_hashes, _hydrated?, _opts), do: @not_implemented

  @impl Explorer.ChainData
  def transactions_by_hashes(_hashes, _opts), do: @not_implemented

  @impl Explorer.ChainData
  def receipts_by_block_numbers(_block_numbers, _opts), do: @not_implemented

  @impl Explorer.ChainData
  def receipts_by_transaction_hashes(_hashes, _opts), do: @not_implemented

  @impl Explorer.ChainData
  def logs(_query, _opts), do: @not_implemented

  @impl Explorer.ChainData
  def balances_at(_requests, _opts), do: @not_implemented

  @impl Explorer.ChainData
  def nonces_at(_requests, _opts), do: @not_implemented

  @impl Explorer.ChainData
  def codes_at(_requests, _opts), do: @not_implemented

  @impl Explorer.ChainData
  def contract_calls(_requests, _abi, _leave_error_as_map, _opts), do: []

  @impl Explorer.ChainData
  def internal_transactions_by_block_numbers(_block_numbers, _opts), do: :ignore

  @impl Explorer.ChainData
  def internal_transactions_by_transactions(_transactions, _opts), do: :ignore

  @impl Explorer.ChainData
  def raw_traces_by_transaction(_transaction, _opts), do: :ignore

  @impl Explorer.ChainData
  def subscribe_new_blocks(_opts), do: :ignore
end

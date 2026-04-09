defmodule Explorer.ChainData.InternalTransaction do
  @moduledoc """
  Canonical internal transaction payload returned by a `Explorer.ChainData`
  backend.

  This wraps the import-ready params map produced by the current JSON-RPC trace
  path until callers are migrated to a richer typed representation.
  """

  @type t :: %__MODULE__{params: map()}

  defstruct [:params]
end

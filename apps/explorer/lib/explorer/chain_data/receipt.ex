defmodule Explorer.ChainData.Receipt do
  @moduledoc """
  Canonical receipt data returned by a `Explorer.ChainData` backend.
  """

  @type t :: %__MODULE__{
          transaction_hash: EthereumJSONRPC.hash() | nil,
          transaction_index: non_neg_integer() | nil,
          block_hash: EthereumJSONRPC.hash() | nil,
          block_number: non_neg_integer() | nil,
          cumulative_gas_used: non_neg_integer() | nil,
          gas_used: non_neg_integer() | nil,
          gas_price: non_neg_integer() | nil,
          created_contract_address_hash: EthereumJSONRPC.address() | nil,
          status: atom() | nil,
          logs_bloom: String.t() | nil,
          logs: [Explorer.ChainData.Log.t()],
          raw: map()
        }

  defstruct [
    :transaction_hash,
    :transaction_index,
    :block_hash,
    :block_number,
    :cumulative_gas_used,
    :gas_used,
    :gas_price,
    :created_contract_address_hash,
    :status,
    :logs_bloom,
    logs: [],
    raw: %{}
  ]
end

defmodule Explorer.ChainData.Receipt.Batch do
  @moduledoc """
  Canonical result for receipt fetches.
  """

  @type t :: %__MODULE__{
          receipts: [Explorer.ChainData.Receipt.t()],
          logs: [Explorer.ChainData.Log.t()],
          errors: [term()],
          raw: map()
        }

  defstruct receipts: [],
            logs: [],
            errors: [],
            raw: %{}
end

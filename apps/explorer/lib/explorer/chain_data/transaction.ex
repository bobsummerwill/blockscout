defmodule Explorer.ChainData.Transaction do
  @moduledoc """
  Canonical transaction data returned by a `Explorer.ChainData` backend.
  """

  @type t :: %__MODULE__{
          hash: EthereumJSONRPC.hash() | nil,
          block_hash: EthereumJSONRPC.hash() | nil,
          block_number: non_neg_integer() | nil,
          index: non_neg_integer() | nil,
          from_address_hash: EthereumJSONRPC.address() | nil,
          to_address_hash: EthereumJSONRPC.address() | nil,
          created_contract_address_hash: EthereumJSONRPC.address() | nil,
          value: non_neg_integer() | nil,
          gas: non_neg_integer() | nil,
          gas_price: non_neg_integer() | nil,
          max_fee_per_gas: non_neg_integer() | nil,
          max_priority_fee_per_gas: non_neg_integer() | nil,
          input: String.t() | nil,
          nonce: non_neg_integer() | nil,
          r: non_neg_integer() | nil,
          s: non_neg_integer() | nil,
          v: non_neg_integer() | nil,
          type: non_neg_integer() | nil,
          status: atom() | nil,
          raw: map()
        }

  defstruct [
    :hash,
    :block_hash,
    :block_number,
    :index,
    :from_address_hash,
    :to_address_hash,
    :created_contract_address_hash,
    :value,
    :gas,
    :gas_price,
    :max_fee_per_gas,
    :max_priority_fee_per_gas,
    :input,
    :nonce,
    :r,
    :s,
    :v,
    :type,
    :status,
    raw: %{}
  ]
end

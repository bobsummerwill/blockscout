defmodule Explorer.ChainData.Log do
  @moduledoc """
  Canonical log data returned by a `Explorer.ChainData` backend.
  """

  @type t :: %__MODULE__{
          address_hash: EthereumJSONRPC.address() | nil,
          topics: [EthereumJSONRPC.hash()],
          data: String.t() | nil,
          block_hash: EthereumJSONRPC.hash() | nil,
          block_number: non_neg_integer() | nil,
          transaction_hash: EthereumJSONRPC.hash() | nil,
          transaction_index: non_neg_integer() | nil,
          index: non_neg_integer() | nil,
          raw: map()
        }

  defstruct [
    :address_hash,
    :data,
    :block_hash,
    :block_number,
    :transaction_hash,
    :transaction_index,
    :index,
    topics: [],
    raw: %{}
  ]
end

defmodule Explorer.ChainData.Log.Query do
  @moduledoc """
  Backend-neutral log query shape.
  """

  @type t :: %__MODULE__{
          from_block: EthereumJSONRPC.block_number() | String.t() | nil,
          to_block: EthereumJSONRPC.block_number() | String.t() | nil,
          block_hash: EthereumJSONRPC.hash() | nil,
          address: EthereumJSONRPC.address() | [EthereumJSONRPC.address()] | nil,
          topics: list() | nil
        }

  defstruct [
    :from_block,
    :to_block,
    :block_hash,
    :address,
    :topics
  ]
end

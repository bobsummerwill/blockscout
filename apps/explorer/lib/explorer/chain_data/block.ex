defmodule Explorer.ChainData.Block do
  @moduledoc """
  Canonical block data returned by a `Explorer.ChainData` backend.
  """

  @type t :: %__MODULE__{
          hash: EthereumJSONRPC.hash() | nil,
          number: non_neg_integer() | nil,
          parent_hash: EthereumJSONRPC.hash() | nil,
          timestamp: DateTime.t() | nil,
          miner_hash: EthereumJSONRPC.address() | nil,
          gas_limit: non_neg_integer() | nil,
          gas_used: non_neg_integer() | nil,
          size: non_neg_integer() | nil,
          nonce: non_neg_integer() | nil,
          difficulty: non_neg_integer() | nil,
          total_difficulty: non_neg_integer() | nil,
          base_fee_per_gas: non_neg_integer() | nil,
          transactions: [Explorer.ChainData.Transaction.t()],
          uncles: [EthereumJSONRPC.hash()],
          withdrawals: [map()],
          raw: map()
        }

  defstruct [
    :hash,
    :number,
    :parent_hash,
    :timestamp,
    :miner_hash,
    :gas_limit,
    :gas_used,
    :size,
    :nonce,
    :difficulty,
    :total_difficulty,
    :base_fee_per_gas,
    transactions: [],
    uncles: [],
    withdrawals: [],
    raw: %{}
  ]
end

defmodule Explorer.ChainData.BlockBatch do
  @moduledoc """
  Canonical result for block batch fetches.
  """

  @type t :: %__MODULE__{
          blocks: [Explorer.ChainData.Block.t()],
          transactions: [Explorer.ChainData.Transaction.t()],
          second_degree_relations: [map()],
          withdrawals: [map()],
          errors: [term()],
          raw: map()
        }

  defstruct blocks: [],
            transactions: [],
            second_degree_relations: [],
            withdrawals: [],
            errors: [],
            raw: %{}
end

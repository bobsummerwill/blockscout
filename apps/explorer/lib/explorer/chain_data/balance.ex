defmodule Explorer.ChainData.Balance.Request do
  @moduledoc """
  Historical balance lookup request.
  """

  @type t :: %__MODULE__{
          address_hash: EthereumJSONRPC.address(),
          block_number: EthereumJSONRPC.block_number() | String.t()
        }

  defstruct [:address_hash, :block_number]
end

defmodule Explorer.ChainData.Balance do
  @moduledoc """
  Historical balance lookup result.
  """

  @type t :: %__MODULE__{
          address_hash: EthereumJSONRPC.address(),
          block_number: EthereumJSONRPC.block_number(),
          value: non_neg_integer()
        }

  defstruct [:address_hash, :block_number, :value]
end

defmodule Explorer.ChainData.Balance.Batch do
  @moduledoc """
  Batched balance lookup result.
  """

  @type t :: %__MODULE__{
          balances: [Explorer.ChainData.Balance.t()],
          errors: [term()]
        }

  defstruct balances: [], errors: []
end

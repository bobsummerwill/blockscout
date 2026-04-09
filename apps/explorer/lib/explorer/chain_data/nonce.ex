defmodule Explorer.ChainData.Nonce.Request do
  @moduledoc """
  Historical nonce lookup request.
  """

  @type t :: %__MODULE__{
          address_hash: EthereumJSONRPC.address(),
          block_number: EthereumJSONRPC.block_number() | String.t()
        }

  defstruct [:address_hash, :block_number]
end

defmodule Explorer.ChainData.Nonce do
  @moduledoc """
  Historical nonce lookup result.
  """

  @type t :: %__MODULE__{
          address_hash: EthereumJSONRPC.address(),
          block_number: EthereumJSONRPC.block_number(),
          value: non_neg_integer()
        }

  defstruct [:address_hash, :block_number, :value]
end

defmodule Explorer.ChainData.Nonce.Batch do
  @moduledoc """
  Batched nonce lookup result.
  """

  @type t :: %__MODULE__{
          nonces: [Explorer.ChainData.Nonce.t()],
          errors: [term()]
        }

  defstruct nonces: [], errors: []
end

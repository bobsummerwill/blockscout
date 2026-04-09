defmodule Explorer.ChainData.Code.Request do
  @moduledoc """
  Historical contract code lookup request.
  """

  @type t :: %__MODULE__{
          address_hash: EthereumJSONRPC.address(),
          block_number: EthereumJSONRPC.block_number() | String.t()
        }

  defstruct [:address_hash, :block_number]
end

defmodule Explorer.ChainData.Code do
  @moduledoc """
  Historical contract code lookup result.
  """

  @type t :: %__MODULE__{
          address_hash: EthereumJSONRPC.address(),
          block_number: EthereumJSONRPC.block_number(),
          value: String.t()
        }

  defstruct [:address_hash, :block_number, :value]
end

defmodule Explorer.ChainData.Code.Batch do
  @moduledoc """
  Batched contract code lookup result.
  """

  @type t :: %__MODULE__{
          codes: [Explorer.ChainData.Code.t()],
          errors: [term()]
        }

  defstruct codes: [], errors: []
end

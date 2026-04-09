defmodule Explorer.ChainData.Call.Request do
  @moduledoc """
  Read-only contract call request.
  """

  @type t :: %__MODULE__{
          contract_address: EthereumJSONRPC.address(),
          method_id: String.t(),
          args: [term()],
          block_number: EthereumJSONRPC.block_number() | nil,
          from: EthereumJSONRPC.address() | nil
        }

  defstruct [:contract_address, :method_id, :args, :block_number, :from]
end

defmodule Explorer.ChainData.Call.Result do
  @moduledoc """
  Read-only contract call result.
  """

  @type t :: {:ok, term()} | {:error, term()}
end

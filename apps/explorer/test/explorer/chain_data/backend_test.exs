defmodule Explorer.ChainData.BackendTest do
  use ExUnit.Case, async: false

  alias Explorer.ChainData.Backend

  setup do
    original = Application.get_env(:explorer, Explorer.ChainData, [])

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.ChainData, original)
    end)

    :ok
  end

  test "impl/0 resolves the configured backend" do
    Application.put_env(:explorer, Explorer.ChainData, backend: Explorer.ChainData.STRATO)

    assert Backend.impl() == Explorer.ChainData.STRATO
  end

  test "impl/0 defaults to the Ethereum JSON-RPC backend" do
    Application.put_env(:explorer, Explorer.ChainData, [])

    assert Backend.impl() == Explorer.ChainData.EthereumJSONRPC
  end
end

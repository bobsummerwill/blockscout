defmodule Explorer.ChainData.STRATO.ConfigTest do
  use ExUnit.Case, async: false

  alias Explorer.ChainData.STRATO.Config

  setup do
    original = Application.get_env(:explorer, Explorer.ChainData.STRATO, [])

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.ChainData.STRATO, original)
    end)

    :ok
  end

  test "get/1 deep merges endpoint overrides from opts" do
    Application.put_env(
      :explorer,
      Explorer.ChainData.STRATO,
      profile: :private_explorer_api,
      base_url: "http://configured",
      recv_timeout: :timer.seconds(10),
      endpoints: [chain_info: "/chain-info", blocks_by_range: "/blocks/range"]
    )

    config =
      Config.get(
        strato: [
          base_url: "http://override",
          endpoints: [blocks_by_range: "/custom-blocks/range"]
        ]
      )

    assert Keyword.get(config, :base_url) == "http://override"
    assert Keyword.get(config, :recv_timeout) == :timer.seconds(10)
    assert Config.endpoint(:chain_info, config) == "/chain-info"
    assert Config.endpoint(:blocks_by_range, config) == "/custom-blocks/range"
  end

  test "get/1 loads the core API endpoint set when configured" do
    Application.put_env(
      :explorer,
      Explorer.ChainData.STRATO,
      profile: "core_api",
      base_url: "http://configured"
    )

    config = Config.get()

    assert Config.profile(config) == :core_api
    assert Config.endpoint(:chain_info, config) == "/eth/v1.2/metadata"
    assert Config.endpoint(:block_last, config) == "/eth/v1.2/block/last"
    assert Config.endpoint(:account_query, config) == "/eth/v1.2/account"
  end
end

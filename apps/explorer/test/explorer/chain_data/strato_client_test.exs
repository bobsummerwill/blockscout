defmodule Explorer.ChainData.STRATO.ClientTest do
  use ExUnit.Case, async: false

  alias Explorer.ChainData.STRATO.Client
  alias Plug.Conn

  defmodule BareMapHttpClient do
    def request(:get, "http://example.com/chain-info", _headers, nil, _opts) do
      %{status_code: 200, body: Jason.encode!(%{"ok" => true}), headers: []}
    end
  end

  setup do
    original_tesla_adapter = Application.get_env(:tesla, :adapter)
    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:tesla, :adapter, original_tesla_adapter)
    end)

    :ok
  end

  test "returns an explicit error when base_url is missing" do
    assert {:error, :strato_base_url_not_configured} = Client.get("/chain-info")
  end

  test "returns decoded JSON bodies for non-2xx responses" do
    bypass = Bypass.open()

    on_exit(fn -> Bypass.down(bypass) end)

    Bypass.expect_once(bypass, "GET", "/chain-info", fn conn ->
      Conn.resp(conn, 500, Jason.encode!(%{"code" => "boom", "message" => "failure"}))
    end)

    assert {:error, {:http_error, 500, %{"code" => "boom", "message" => "failure"}}} =
             Client.get("/chain-info", strato: [base_url: base_url(bypass)])
  end

  test "preserves raw non-JSON bodies on successful responses" do
    bypass = Bypass.open()

    on_exit(fn -> Bypass.down(bypass) end)

    Bypass.expect_once(bypass, "GET", "/chain-info", fn conn ->
      Conn.resp(conn, 200, "not-json")
    end)

    assert {:ok, %{"raw_body" => "not-json"}} =
             Client.get("/chain-info", strato: [base_url: base_url(bypass)])
  end

  test "sends the configured bearer token as an authorization header" do
    bypass = Bypass.open()

    on_exit(fn -> Bypass.down(bypass) end)

    Bypass.expect_once(bypass, "GET", "/chain-info", fn conn ->
      assert ["Bearer test-token"] == Plug.Conn.get_req_header(conn, "authorization")
      assert ["curl/8.0 (Blockscout STRATO client)"] == Plug.Conn.get_req_header(conn, "user-agent")
      Conn.resp(conn, 200, Jason.encode!(%{"ok" => true}))
    end)

    assert {:ok, %{"ok" => true}} =
             Client.get("/chain-info", strato: [base_url: base_url(bypass), bearer_token: "test-token"])
  end

  test "preserves a pathful base_url when joining endpoint paths" do
    bypass = Bypass.open()

    on_exit(fn -> Bypass.down(bypass) end)

    Bypass.expect_once(bypass, "GET", "/strato-api/chain-info", fn conn ->
      Conn.resp(conn, 200, Jason.encode!(%{"ok" => true}))
    end)

    assert {:ok, %{"ok" => true}} =
             Client.get("/chain-info", strato: [base_url: "#{base_url(bypass)}/strato-api"])
  end

  test "normalizes bare response maps from the configured http client" do
    assert {:ok, %{"ok" => true}} =
             Client.get("/chain-info", strato: [base_url: "http://example.com", http_client: BareMapHttpClient])
  end

  defp base_url(bypass), do: "http://localhost:#{bypass.port}"
end

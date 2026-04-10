defmodule Explorer.ChainData.STRATOTest do
  use ExUnit.Case, async: false

  alias Explorer.ChainData.{
    Balance,
    Log,
    STRATO
  }

  alias Plug.Conn

  @block_by_tag_payload fixture("block_by_tag.json")
  @blocks_by_range_payload fixture("blocks_by_range.json")
  @transactions_by_hashes_payload fixture("transactions_by_hashes.json")
  @transactions_count_payload fixture("transactions_count_by_block_numbers.json")
  @receipts_payload fixture("receipts_by_block_numbers.json")
  @balances_payload fixture("balances.json")
  @nonces_payload fixture("nonces.json")
  @codes_payload fixture("codes.json")
  @logs_payload fixture("logs.json")

  setup do
    original_tesla_adapter = Application.get_env(:tesla, :adapter)
    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:tesla, :adapter, original_tesla_adapter)
    end)

    :ok
  end

  describe "private STRATO endpoint assumptions" do
    test "block_by_tag/2 fetches /blocks/by-tag/:tag with hydrated query param" do
      bypass = Bypass.open()

      on_exit(fn -> Bypass.down(bypass) end)

      Bypass.expect_once(bypass, "GET", "/blocks/by-tag/latest", fn conn ->
        assert conn.query_string == "hydrated=true"

        Conn.resp(
          conn,
          200,
          Jason.encode!(@block_by_tag_payload)
        )
      end)

      assert {:ok, %{hash: "0xblock", number: 1}} =
               STRATO.block_by_tag(:latest, strato: [base_url: base_url(bypass)])
    end

    test "transactions_by_hashes/2 posts hashes to /transactions/by-hash" do
      bypass = Bypass.open()

      on_exit(fn -> Bypass.down(bypass) end)

      Bypass.expect_once(bypass, "POST", "/transactions/by-hash", fn conn ->
        assert %{"hashes" => ["0xtx1", "0xtx2"]} = Jason.decode!(read_body(conn))

        Conn.resp(
          conn,
          200,
          Jason.encode!(@transactions_by_hashes_payload)
        )
      end)

      assert {:ok, [%{hash: "0xtx1", block_number: 2}, %{hash: "0xtx2", block_number: 3}], []} =
               STRATO.transactions_by_hashes(["0xtx1", "0xtx2"], strato: [base_url: base_url(bypass)])
    end

    test "balances_at/2 posts normalized requests to /state/balances" do
      bypass = Bypass.open()

      on_exit(fn -> Bypass.down(bypass) end)

      Bypass.expect_once(bypass, "POST", "/state/balances", fn conn ->
        assert %{
                 "requests" => [
                   %{"address_hash" => "0xabc", "block_number" => 12}
                 ]
               } = Jason.decode!(read_body(conn))

        Conn.resp(
          conn,
          200,
          Jason.encode!(@balances_payload)
        )
      end)

      assert {:ok, %{balances: [%Balance{address_hash: "0xabc", block_number: 12, value: 100}], errors: []}} =
               STRATO.balances_at(
                 [%Balance.Request{address_hash: "0xabc", block_number: 12}],
                 strato: [base_url: base_url(bypass)]
               )
    end

    test "logs/2 posts the private log search payload to /logs/search" do
      bypass = Bypass.open()

      on_exit(fn -> Bypass.down(bypass) end)

      Bypass.expect_once(bypass, "POST", "/logs/search", fn conn ->
        assert %{
                 "from_block" => 10,
                 "to_block" => 12,
                 "address" => ["0x1", "0x2"],
                 "topics" => [["0xtopic0"], nil]
               } = Jason.decode!(read_body(conn))

        Conn.resp(
          conn,
          200,
          Jason.encode!(@logs_payload)
        )
      end)

      assert {:ok, [%Log{address_hash: "0x1", transaction_hash: "0xtx", block_number: 12, index: 0}]} =
               STRATO.logs(
                 %Log.Query{from_block: 10, to_block: 12, address: ["0x1", "0x2"], topics: [["0xtopic0"], nil]},
                 strato: [base_url: base_url(bypass)]
               )
    end

    test "blocks_by_range/3 posts the expected range payload to /blocks/range" do
      bypass = Bypass.open()

      on_exit(fn -> Bypass.down(bypass) end)

      Bypass.expect_once(bypass, "POST", "/blocks/range", fn conn ->
        assert %{"from" => 16, "to" => 17, "hydrated" => true} = Jason.decode!(read_body(conn))

        Conn.resp(conn, 200, Jason.encode!(@blocks_by_range_payload))
      end)

      assert {:ok, %{blocks: [%{hash: "0xblock1"}, %{hash: "0xblock2"}]}} =
               STRATO.blocks_by_range(16..17, true, strato: [base_url: base_url(bypass)])
    end

    test "transactions_count_by_block_numbers/2 posts the block list to /transactions/count/by-block-number" do
      bypass = Bypass.open()

      on_exit(fn -> Bypass.down(bypass) end)

      Bypass.expect_once(bypass, "POST", "/transactions/count/by-block-number", fn conn ->
        assert %{"block_numbers" => [10, 11]} = Jason.decode!(read_body(conn))

        Conn.resp(conn, 200, Jason.encode!(@transactions_count_payload))
      end)

      assert {:ok, %{transactions_count_map: %{10 => 2, 11 => 0}, errors: []}} =
               STRATO.transactions_count_by_block_numbers([10, 11], strato: [base_url: base_url(bypass)])
    end

    test "receipts_by_block_numbers/2 posts the block list to /receipts/by-block-number" do
      bypass = Bypass.open()

      on_exit(fn -> Bypass.down(bypass) end)

      Bypass.expect_once(bypass, "POST", "/receipts/by-block-number", fn conn ->
        assert %{"block_numbers" => [16]} = Jason.decode!(read_body(conn))

        Conn.resp(conn, 200, Jason.encode!(@receipts_payload))
      end)

      assert {:ok, %{receipts: [%{transaction_hash: "0xtx"}], logs: [%{address_hash: "0xlog"}]}} =
               STRATO.receipts_by_block_numbers([16], strato: [base_url: base_url(bypass)])
    end

    test "nonces_at/2 posts normalized requests to /state/nonces" do
      bypass = Bypass.open()

      on_exit(fn -> Bypass.down(bypass) end)

      Bypass.expect_once(bypass, "POST", "/state/nonces", fn conn ->
        assert %{
                 "requests" => [
                   %{"address_hash" => "0xabc", "block_number" => 32}
                 ]
               } = Jason.decode!(read_body(conn))

        Conn.resp(conn, 200, Jason.encode!(@nonces_payload))
      end)

      assert {:ok, %{nonces: [%{address_hash: "0xabc", block_number: 32, value: 4}], errors: []}} =
               STRATO.nonces_at(
                 [%Explorer.ChainData.Nonce.Request{address_hash: "0xabc", block_number: 32}],
                 strato: [base_url: base_url(bypass)]
               )
    end

    test "codes_at/2 posts normalized requests to /state/codes" do
      bypass = Bypass.open()

      on_exit(fn -> Bypass.down(bypass) end)

      Bypass.expect_once(bypass, "POST", "/state/codes", fn conn ->
        assert %{
                 "requests" => [
                   %{"address_hash" => "0xabc", "block_number" => 32}
                 ]
               } = Jason.decode!(read_body(conn))

        Conn.resp(conn, 200, Jason.encode!(@codes_payload))
      end)

      assert {:ok, %{codes: [%{address_hash: "0xabc", block_number: 32, value: "0x6000"}], errors: []}} =
               STRATO.codes_at(
                 [%Explorer.ChainData.Code.Request{address_hash: "0xabc", block_number: 32}],
                 strato: [base_url: base_url(bypass)]
               )
    end
  end

  defp base_url(bypass), do: "http://localhost:#{bypass.port}"

  defp read_body(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    _ = conn
    body
  end

  defp fixture(name) do
    "#{File.cwd!()}/test/support/fixture/chain_data/strato/#{name}"
    |> File.read!()
    |> Jason.decode!()
  end
end

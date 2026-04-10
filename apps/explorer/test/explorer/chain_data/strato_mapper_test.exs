defmodule Explorer.ChainData.STRATO.MapperTest do
  use ExUnit.Case, async: true

  alias Explorer.ChainData.{
    Balance,
    Block,
    Log,
    Nonce,
    Receipt,
    Transaction
  }

  alias Explorer.ChainData.STRATO.Mapper

  @blocks_by_range_payload fixture("blocks_by_range.json")
  @receipts_payload fixture("receipts_by_block_numbers.json")
  @balances_payload fixture("balances.json")
  @nonces_payload fixture("nonces.json")
  @codes_payload fixture("codes.json")
  @transactions_count_payload fixture("transactions_count_by_block_numbers.json")

  describe "chain_info/1" do
    test "returns an explicit error for missing payloads" do
      assert {:error, :missing_chain_info} = Mapper.chain_info(nil)
    end

    test "parses camelCase payloads into canonical chain info" do
      assert {:ok, %{chain_id: 1516, head: 42, safe_head: 40}} =
               Mapper.chain_info(%{
                 "chainId" => "1516",
                 "headBlockNumber" => "0x2a",
                 "safeHead" => 40
               })
    end

    test "parses STRATO metadata payloads via networkID" do
      assert {:ok, %{chain_id: 1516, head: 42, safe_head: nil}} =
               Mapper.chain_info(%{
                 "networkID" => "1516",
                 "head" => 42
               })
    end
  end

  describe "block_batch/1" do
    test "returns an empty batch for nil payloads" do
      assert %{blocks: [], transactions: [], errors: []} = Mapper.block_batch(nil)
    end

    test "maps blocks and nested transactions into canonical DTOs" do
      batch = Mapper.block_batch(@blocks_by_range_payload)

      assert %{
               blocks: [
                 %Block{
                   hash: "0xblock1",
                   number: 16,
                   parent_hash: "0xparent",
                   transactions: [
                     %Transaction{hash: "0xtx1", index: 0, from_address_hash: "0xfrom1", to_address_hash: "0xto1"}
                   ]
                 },
                 %Block{hash: "0xblock2", number: 17, transactions: []}
               ],
               transactions: [%Transaction{hash: "0xtx1", block_number: 16, type: 2, status: :ok}]
             } = batch
    end

    test "tolerates sparse block payloads" do
      assert %{
               blocks: [%Block{hash: "0xsparse", number: nil, transactions: []}],
               transactions: []
             } = Mapper.block_batch(%{"blocks" => [%{"hash" => "0xsparse"}]})
    end

    test "maps STRATO core API blocks with nested blockData and receiptTransactions" do
      batch =
        Mapper.block_batch([
          %{
            "blockHash" => "0xcoreblock",
            "blockData" => %{
              "parentHash" => "0xparent",
              "coinbase" => "0xminer",
              "number" => 42,
              "gasLimit" => 30_000_000,
              "gasUsed" => 21_000,
              "timestamp" => "2024-01-01T00:00:00Z",
              "nonce" => 7,
              "difficulty" => 9
            },
            "receiptTransactions" => [
              %{
                "hash" => "0xcoretx",
                "from" => "0xfrom",
                "to" => "0xto",
                "blockNumber" => 42,
                "gasLimit" => 21_000,
                "gasPrice" => 4,
                "value" => 5,
                "txData" => [1, 2, 255]
              }
            ]
          }
        ])

      assert %{
               blocks: [
                 %Block{
                   hash: "0xcoreblock",
                   number: 42,
                   parent_hash: "0xparent",
                   miner_hash: "0xminer",
                   transactions: [%Transaction{hash: "0xcoretx", input: "0x0102ff"}]
                 }
               ],
               transactions: [%Transaction{hash: "0xcoretx", gas: 21_000, gas_price: 4}]
             } = batch
    end
  end

  describe "receipt_batch/1" do
    test "returns an empty receipt batch for nil payloads" do
      assert %{receipts: [], logs: [], errors: []} = Mapper.receipt_batch(nil)
    end

    test "associates logs with their receipt" do
      batch = Mapper.receipt_batch(@receipts_payload)

      assert %{
               receipts: [
                 %Receipt{
                   transaction_hash: "0xtx",
                   transaction_index: 1,
                   status: :ok,
                   logs: [%Log{address_hash: "0xlog", index: 0}]
                 }
               ],
               logs: [%Log{transaction_hash: "0xtx", block_number: 16}]
             } = batch
    end
  end

  describe "state batch mappers" do
    test "map balances, nonces, and codes from the private state endpoints" do
      assert %{
               balances: [%Balance{address_hash: "0xabc", block_number: 32, value: 15}],
               errors: []
             } =
               Mapper.balance_batch(%{
                 "balances" => [%{"addressHash" => "0xabc", "blockNumber" => "0x20", "balance" => "0xf"}]
               })

      assert %{
               nonces: [%Nonce{address_hash: "0xabc", block_number: 32, value: 4}],
               errors: []
             } = Mapper.nonce_batch(@nonces_payload)

      assert %{
               codes: [%Explorer.ChainData.Code{address_hash: "0xabc", block_number: 32, value: "0x6000"}],
               errors: []
             } = Mapper.code_batch(@codes_payload)
    end

    test "maps STRATO account payloads into balances and nonces" do
      account_payload = %{
        "balances" => [
          %{"address" => "0xabc", "latestBlockNum" => 32, "balance" => "15"}
        ],
        "nonces" => [
          %{"address" => "0xabc", "latestBlockNum" => 32, "nonce" => 8}
        ]
      }

      assert %{
               balances: [%Balance{address_hash: "0xabc", block_number: 32, value: 15}],
               errors: []
             } = Mapper.balance_batch(account_payload)

      assert %{
               nonces: [%Nonce{address_hash: "0xabc", block_number: 32, value: 8}],
               errors: []
             } = Mapper.nonce_batch(account_payload)
    end
  end

  describe "transactions_count/1" do
    test "returns an empty count map for nil payloads" do
      assert {:ok, %{transactions_count_map: %{}, errors: []}} = Mapper.transactions_count(nil)
    end

    test "normalizes mixed-format count maps" do
      assert {:ok, %{transactions_count_map: %{10 => 2, 11 => 0}, errors: []}} =
               Mapper.transactions_count(@transactions_count_payload)
    end
  end

  defp fixture(name) do
    "#{File.cwd!()}/test/support/fixture/chain_data/strato/#{name}"
    |> File.read!()
    |> Jason.decode!()
  end
end

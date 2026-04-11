# STRATO Core API Gaps For Blockscout

This note captures what the current STRATO `/eth/v1.2` API can already support
for `Explorer.ChainData.STRATO` and what still requires STRATO-side work before
Blockscout can run against the `:core_api` profile beyond partial read support.

## Supported Today

The current STRATO core API already provides enough data for these
`Explorer.ChainData` callbacks:

- `chain_info/1`
  - mapped from `GET /eth/v1.2/metadata`
  - head block derived from `GET /eth/v1.2/block/last/1`
- `block_by_tag(:latest, ...)`
  - mapped from `GET /eth/v1.2/block/last/1`
- `blocks_by_range/3`
  - mapped from `GET /eth/v1.2/block?minnumber=...&maxnumber=...`
- `blocks_by_numbers/3`
  - mapped via fan-out `GET /eth/v1.2/block?number=...`
- `blocks_by_hashes/3`
  - mapped via fan-out `GET /eth/v1.2/block?hash=...`
- `transactions_by_hashes/2`
  - mapped via fan-out `GET /eth/v1.2/transaction?hash=...`
- `transactions_count_by_block_numbers/2`
  - derived from block payload transaction lists
- `balances_at/2`
  - mapped from `GET /eth/v1.2/account?address=...&maxnumber=...`
- `nonces_at/2`
  - mapped from `GET /eth/v1.2/account?address=...&maxnumber=...`

This is enough to make the `:core_api` profile useful as a concrete,
non-speculative baseline.

## Missing For Full Explorer Support

### 1. Receipt Import

Blockscout needs canonical receipt batches with:

- `transaction_hash`
- `transaction_index`
- `block_hash`
- `block_number`
- `gas_used`
- `cumulative_gas_used`
- `status`
- `logs`
- `logs_bloom`

Current STRATO core API surface:

- `GET /eth/v1.2/transactionResult/:txHash`
- `POST /eth/v1.2/transactionResult/batch`

Problem:

- `TransactionResult` is execution-result oriented, not explorer-receipt
  oriented.
- The current STRATO JSON-RPC receipt adapter already hardcodes
  `transactionIndex = 0`, `logs = []`, and a zero `logsBloom`, which confirms
  those fields are not available from the current path in explorer-grade form.

Needed STRATO addition:

- either a new canonical receipt endpoint
- or a richer batch transaction-result endpoint that includes:
  - transaction position inside the block
  - emitted logs
  - bloom
  - per-receipt gas totals in explorer-consumable shape

### 2. Log Search

Blockscout’s indexing and token-transfer extraction depends on range log search
with standard filters:

- `from_block`
- `to_block`
- optional `block_hash`
- address filter
- topic filters

Current STRATO core API:

- no log search endpoint under `/eth/v1.2`

Needed STRATO addition:

- a log-search endpoint with deterministic ordering and no hidden pagination, or
- an event/log index that can be exposed through a Blockscout-oriented query API

Without this, token transfer extraction and many receipt-driven explorer paths
cannot be supported.

### 3. Contract Bytecode Reads

Blockscout’s `codes_at/2` path needs canonical contract bytecode hex for a
specific address at a specific block height.

Current STRATO core API:

- `GET /eth/v1.2/account?...` returns account state and `codeHash`
- `GET /eth/v1.2/code/:codeHash` returns `SourceMap`

Problem:

- `SourceMap` is contract/source metadata, not canonical deployed bytecode
  suitable for Blockscout’s `contract_code` indexing path.
- The account response does not provide bytecode directly.
- The current core API does not expose an address-and-block -> bytecode read.

Needed STRATO addition:

- a historical bytecode endpoint keyed by address + block height, or
- an address + block -> code pointer lookup plus code-bytecode resolution path
  that returns deployed bytecode hex rather than source metadata

Until then, `codes_at/2` should remain explicitly unsupported for
`:core_api`.

### 4. Internal Transactions / Traces

Current STRATO core API has no explorer-ready trace surface for:

- `internal_transactions_by_block_numbers/2`
- `internal_transactions_by_transactions/2`
- `raw_traces_by_transaction/2`
- `first_trace/2`

Needed STRATO addition:

- a trace/index endpoint or pre-materialized internal transaction dataset

This is still a separate milestone from block/tx/account reads.

### 5. Historical Contract Calls

Current STRATO adapter still leaves `contract_calls/4` unsupported.

Needed STRATO addition:

- a stable read-only call endpoint with clear block-tag/height semantics and
  Ethereum-like return/error normalization

### 6. Safe/Finalized Head Semantics

Current `:core_api` support only maps `:latest`.

Needed STRATO addition:

- explicit finalized/safe head semantics if Blockscout should expose them

## Practical Next Endpoints To Add On STRATO

The initial private explorer additions are now in place for:

- receipts
- logs
- bytecode
- synthetic first-trace
- raw trace text

The remaining STRATO-side additions that materially unblock deeper Blockscout
trace parity are:

1. `POST /internal-transactions/by-block-number`
2. `POST /internal-transactions/by-transaction`

Those are the missing surfaces for:

- nested internal transaction indexing
- internal transaction pages beyond the synthetic root trace

The exact request and response contract for the currently implemented private
endpoints is documented in
[`STRATO_PRIVATE_EXPLORER_API_SPEC.md`](./STRATO_PRIVATE_EXPLORER_API_SPEC.md).

## Recommendation

Use the current `:core_api` profile as the verified baseline for:

- blocks
- transactions
- tx counts
- balances
- nonces

Then add STRATO-side explorer-oriented endpoints for:

- nested internal transactions

Only after that should the STRATO backend become a serious candidate for
running the full Blockscout indexer flow.

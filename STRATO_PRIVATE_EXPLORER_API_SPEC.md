# STRATO Private Explorer API Spec For Blockscout

This document defines the private STRATO-side HTTP API expected by
`Explorer.ChainData.STRATO` when running in the `:private_explorer_api`
profile.

It is intentionally **not** Ethereum JSON-RPC. It is an internal,
Blockscout-oriented contract designed to expose the exact data the
`Explorer.ChainData` behaviour needs.

Base configuration in Blockscout:

- backend: `Explorer.ChainData.STRATO`
- profile: `:private_explorer_api`
- base URL: STRATO host root, for example `http://strato-host:3000`
- endpoint paths are resolved under `/eth/v1.2/blockscout`

## General Rules

- Transport: HTTP JSON
- Success: `2xx`
- Errors: non-`2xx` with a JSON body when possible
- Ordering:
  - blocks sorted ascending by block number unless otherwise noted
  - transactions sorted by block number then transaction index
  - logs sorted by block number, transaction index, log index
- Responses may include:
  - `errors`: list of partial failures
  - `raw` is not part of the API; it is Blockscout-side adapter state only

## Canonical Shapes

### Block

```json
{
  "hash": "0x...",
  "number": 16,
  "parent_hash": "0x...",
  "timestamp": "2024-01-01T00:00:00Z",
  "miner_hash": "0x...",
  "gas_limit": 30000000,
  "gas_used": 21000,
  "size": 1234,
  "nonce": 7,
  "difficulty": 1,
  "total_difficulty": 1,
  "base_fee_per_gas": 0,
  "transactions": [],
  "uncles": [],
  "withdrawals": []
}
```

### Transaction

```json
{
  "hash": "0x...",
  "block_hash": "0x...",
  "block_number": 16,
  "index": 0,
  "from_address_hash": "0x...",
  "to_address_hash": "0x...",
  "created_contract_address_hash": "0x...",
  "value": 0,
  "gas": 21000,
  "gas_price": 1,
  "max_fee_per_gas": 1,
  "max_priority_fee_per_gas": 1,
  "input": "0x",
  "nonce": 3,
  "type": 2,
  "status": "success"
}
```

Accepted status values by the current mapper:

- success-like: `1`, `"1"`, `"0x1"`, `true`, `"ok"`, `"success"`, `"succeeded"`
- failure-like: `0`, `"0"`, `"0x0"`, `false`, `"error"`, `"failed"`, `"failure"`

### Receipt

```json
{
  "transaction_hash": "0x...",
  "transaction_index": 0,
  "block_hash": "0x...",
  "block_number": 16,
  "cumulative_gas_used": 21000,
  "gas_used": 21000,
  "gas_price": 1,
  "created_contract_address_hash": "0x...",
  "status": "success",
  "logs_bloom": "0x..."
}
```

### Log

```json
{
  "address_hash": "0x...",
  "topics": ["0x..."],
  "data": "0x...",
  "block_hash": "0x...",
  "block_number": 16,
  "transaction_hash": "0x...",
  "transaction_index": 0,
  "index": 0
}
```

### Balance / Nonce / Code

```json
{
  "address_hash": "0x...",
  "block_number": 32,
  "value": 15
}
```

For code:

```json
{
  "address_hash": "0x...",
  "block_number": 32,
  "value": "0x6000"
}
```

## Endpoints

### `GET /eth/v1.2/blockscout/chain-info`

Purpose:

- resolve `chain_info/1`

Response:

```json
{
  "chain_id": 1516,
  "head": 42,
  "safe_head": 40
}
```

Also accepted by the current mapper:

- `chainId`
- `headBlockNumber`
- `safeHead`

### `GET /eth/v1.2/blockscout/blocks/by-tag/:tag?hydrated=true`

Purpose:

- resolve `block_by_tag/2`

Supported tags expected by Blockscout:

- `latest`
- optionally `safe`
- optionally `pending`

Response:

- a single canonical `Block`

### `POST /eth/v1.2/blockscout/blocks/range`

Purpose:

- resolve `blocks_by_range/3`

Request:

```json
{
  "from": 16,
  "to": 17,
  "hydrated": true
}
```

Response:

```json
{
  "blocks": [
    {
      "hash": "0xblock1",
      "number": 16,
      "parent_hash": "0xparent",
      "transactions": [
        {
          "hash": "0xtx1",
          "block_number": 16,
          "index": 0,
          "from_address_hash": "0xfrom1",
          "to_address_hash": "0xto1",
          "type": 2,
          "status": "success"
        }
      ]
    },
    {
      "hash": "0xblock2",
      "number": 17,
      "transactions": []
    }
  ],
  "errors": []
}
```

Notes:

- if `hydrated` is `false`, blocks may omit embedded transaction objects and the
  response may instead provide top-level `transactions`

### `POST /blocks/by-number`

Purpose:

- resolve `blocks_by_numbers/3`

Request:

```json
{
  "block_numbers": [16, 17],
  "hydrated": true
}
```

Response:

- same shape as `POST /blocks/range`

### `POST /blocks/by-hash`

Purpose:

- resolve `blocks_by_hashes/3`

Request:

```json
{
  "hashes": ["0xblock1", "0xblock2"],
  "hydrated": true
}
```

Response:

- same shape as `POST /blocks/range`

### `POST /transactions/by-hash`

Purpose:

- resolve `transactions_by_hashes/2`

Request:

```json
{
  "hashes": ["0xtx1", "0xtx2"]
}
```

Response:

```json
{
  "transactions": [
    {
      "hash": "0xtx1",
      "block_number": 2
    },
    {
      "hash": "0xtx2",
      "block_number": 3
    }
  ],
  "errors": []
}
```

The adapter also tolerates:

- a raw JSON array of transaction objects

### `POST /transactions/count/by-block-number`

Purpose:

- resolve `transactions_count_by_block_numbers/2`

Request:

```json
{
  "block_numbers": [10, 11]
}
```

Response:

```json
{
  "transactions_count_map": {
    "10": 2,
    "11": 0
  },
  "errors": []
}
```

Camel-case `transactionsCountMap` is also accepted.

### `POST /transactions/first-trace`

Purpose:

- resolve `first_trace/2`
- provide a synthetic top-level trace derived from persisted transaction and
  transaction-result data

Request:

```json
[
  {
    "block_hash": "0xblock",
    "block_number": 12,
    "hash_data": "0xtx",
    "transaction_index": 1
  }
]
```

Response:

```json
{
  "items": [
    {
      "block_hash": "0xblock",
      "block_number": 12,
      "first_trace": {
        "transaction_hash": "0xtx",
        "type": "call",
        "call_type": "call",
        "from_address_hash": "0xfrom",
        "to_address_hash": "0xto",
        "gas": 21000,
        "gas_used": 20000,
        "input": "0x1234",
        "output": "0x5678",
        "trace_address": [],
        "index": 0,
        "transaction_index": 1,
        "value": 0
      }
    }
  ],
  "errors": []
}
```

Notes:

- this is intentionally a synthetic root trace, not a full nested internal-call tree
- failed transactions should include `error` and omit success-only fields like `gas_used`

### `POST /transactions/raw-traces`

Purpose:

- resolve `raw_traces_by_transaction/2`
- expose persisted STRATO trace/debug text for Blockscout’s raw-trace page

Request:

```json
{
  "hash": "0xtx"
}
```

Response:

```json
{
  "traces": [
    {
      "transaction_hash": "0xtx",
      "block_hash": "0xblock",
      "block_number": 12,
      "transaction_index": 1,
      "status": "success",
      "message": "",
      "response": "0x5678",
      "trace": "CALL 0xdeadbeef"
    }
  ],
  "errors": []
}
```

### `POST /receipts/by-block-number`

Purpose:

- resolve `receipts_by_block_numbers/2`

Request:

```json
{
  "block_numbers": [16]
}
```

Response:

```json
{
  "receipts": [
    {
      "transaction_hash": "0xtx",
      "transaction_index": 1,
      "block_hash": "0xblock1",
      "block_number": 16,
      "cumulative_gas_used": 21000,
      "gas_used": 21000,
      "status": "success",
      "logs_bloom": "0xabc"
    }
  ],
  "logs": [
    {
      "address_hash": "0xlog",
      "transaction_hash": "0xtx",
      "block_number": 16,
      "transaction_index": 1,
      "index": 0,
      "topics": ["0xtopic0"],
      "data": "0x"
    }
  ],
  "errors": []
}
```

Requirements:

- logs must include transaction hash/index and log index
- receipts and logs must be self-consistent

### `POST /receipts/by-transaction-hash`

Purpose:

- resolve `receipts_by_transaction_hashes/2`

Request:

```json
{
  "hashes": ["0xtx1", "0xtx2"]
}
```

Response:

- same shape as `POST /receipts/by-block-number`

### `POST /logs/search`

Purpose:

- resolve `logs/2`

Request:

```json
{
  "from_block": 10,
  "to_block": 12,
  "address": ["0x1", "0x2"],
  "topics": [["0xtopic0"], null]
}
```

Supported fields:

- `from_block`
- `to_block`
- `block_hash`
- `address`
  - string or list is acceptable if the server normalizes it
- `topics`
  - array with nullable positions

Response:

```json
{
  "logs": [
    {
      "address_hash": "0x1",
      "transaction_hash": "0xtx",
      "block_number": 12,
      "transaction_index": 0,
      "index": 0,
      "topics": ["0xtopic0"],
      "data": "0x"
    }
  ]
}
```

The adapter also tolerates a raw JSON array of log objects.

### `POST /state/balances`

Purpose:

- resolve `balances_at/2`

Request:

```json
{
  "requests": [
    {
      "address_hash": "0xabc",
      "block_number": 12
    }
  ]
}
```

Response:

```json
{
  "balances": [
    {
      "address_hash": "0xabc",
      "block_number": 12,
      "value": 100
    }
  ],
  "errors": []
}
```

### `POST /state/nonces`

Purpose:

- resolve `nonces_at/2`

Request:

```json
{
  "requests": [
    {
      "address_hash": "0xabc",
      "block_number": 32
    }
  ]
}
```

Response:

```json
{
  "nonces": [
    {
      "address_hash": "0xabc",
      "block_number": 32,
      "value": 4
    }
  ],
  "errors": []
}
```

### `POST /state/codes`

Purpose:

- resolve `codes_at/2`

Request:

```json
{
  "requests": [
    {
      "address_hash": "0xabc",
      "block_number": 32
    }
  ]
}
```

Response:

```json
{
  "codes": [
    {
      "address_hash": "0xabc",
      "block_number": 32,
      "value": "0x6000"
    }
  ],
  "errors": []
}
```

Requirements:

- `value` must be canonical bytecode hex
- source metadata is not sufficient for this endpoint

## Partial Failure Semantics

Batch endpoints may return partial success when some items fail.

Recommended pattern:

```json
{
  "balances": [
    {
      "address_hash": "0xabc",
      "block_number": 12,
      "value": 100
    }
  ],
  "errors": [
    {
      "request": {
        "address_hash": "0xdef",
        "block_number": 12
      },
      "reason": "not_found"
    }
  ]
}
```

## Not Yet In Scope

These are not part of the current private API contract:

- `contract_calls/4`
- `internal_transactions_by_block_numbers/2`
- `internal_transactions_by_transactions/2`
- `raw_traces_by_transaction/2`
- `first_trace/2`
- websocket subscriptions

They should be added only after receipts, logs, and bytecode are solid.

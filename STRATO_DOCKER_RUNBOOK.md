# Blockscout Against STRATO

This runbook describes the current local Docker path for running Blockscout against STRATO using the private Blockscout API profile.

Related integration docs:

- [STRATO_PRIVATE_EXPLORER_API_SPEC.md](STRATO_PRIVATE_EXPLORER_API_SPEC.md)
- [STRATO_CORE_API_GAPS.md](STRATO_CORE_API_GAPS.md)

## Current Integration Shape

Blockscout currently expects two STRATO-facing services:

- a private Blockscout-oriented HTTP API for canonical explorer data
- the existing STRATO Ethereum JSON-RPC shim for the remaining RPC-specific paths that have not been fully removed yet

The private API is selected with:

- `CHAIN_DATA_BACKEND=strato`
- `STRATO_API_PROFILE=private_explorer_api`

The compose overlay for this setup is:

- [docker-compose/strato.yml](/home/icetiger/Projects/blockscout/docker-compose/strato.yml)

## Expected STRATO Endpoints

The overlay assumes:

- private Blockscout API base URL:
  - `http://host.docker.internal:3000`
- STRATO Ethereum JSON-RPC shim:
  - `http://host.docker.internal:8081/rpc`

If your STRATO deployment uses different ports or prefixes, override these environment variables before starting Blockscout:

- `STRATO_API_URL`
- `ETHEREUM_JSONRPC_HTTP_URL`
- `ETHEREUM_JSONRPC_TRACE_URL`
- `ETHEREUM_JSONRPC_WS_URL`
- `CHAIN_ID`

For a local STRATO node started with `strato-up`, the direct API on port `3000` can be used for Blockscout's private explorer integration without going through the nginx OAuth layer.

If you intentionally point `STRATO_API_URL` at the nginx-proxied route on port `8081`, export a bearer token before starting Blockscout:

```bash
export STRATO_API_AUTH_TOKEN="$(
  python3 - <<'PY'
import json
from pathlib import Path

token = json.loads(Path('~/Projects/strato-platform/mynode/secrets/oauth_token').expanduser().read_text())
print(token['access_token'])
PY
)"
```

## Start Command

From the Blockscout repo root:

```bash
docker compose \
  -f docker-compose/docker-compose.yml \
  -f docker-compose/strato.yml \
  up -d
```

## Notes

- `INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER=true` is set in the STRATO overlay because STRATO does not currently provide pending transaction parity.
- The integration is strongest on canonical explorer reads:
  - blocks
  - transactions
  - receipts
  - logs
  - balances
  - nonces
  - codes
  - first trace / raw traces
  - synthetic internal transactions
- Internal transactions are currently synthetic root traces, not full nested call trees.
- Remaining RPC-specific behavior still depends on the STRATO JSON-RPC shim, so the integration is not yet a pure private-API-only runtime.

## Recommended Verification

After startup:

1. check backend logs for successful migrations and indexer startup
2. confirm the backend can fetch latest chain info from the private STRATO API
3. confirm new blocks, receipts, and logs import cleanly
4. inspect one transaction page with internal transactions enabled

defmodule Explorer.ChainData.STRATO.Config do
  @moduledoc false

  @private_explorer_api_endpoints [
    chain_info: "/eth/v1.2/blockscout/chain-info",
    block_by_tag: "/eth/v1.2/blockscout/blocks/by-tag",
    blocks_by_range: "/eth/v1.2/blockscout/blocks/range",
    blocks_by_numbers: "/eth/v1.2/blockscout/blocks/by-number",
    blocks_by_hashes: "/eth/v1.2/blockscout/blocks/by-hash",
    transactions_by_hashes: "/eth/v1.2/blockscout/transactions/by-hash",
    transactions_count_by_block_numbers: "/eth/v1.2/blockscout/transactions/count/by-block-number",
    transactions_first_trace: "/eth/v1.2/blockscout/transactions/first-trace",
    transactions_raw_traces: "/eth/v1.2/blockscout/transactions/raw-traces",
    internal_transactions_by_block_numbers: "/eth/v1.2/blockscout/internal-transactions/by-block-number",
    internal_transactions_by_transactions: "/eth/v1.2/blockscout/internal-transactions/by-transaction",
    receipts_by_block_numbers: "/eth/v1.2/blockscout/receipts/by-block-number",
    receipts_by_transaction_hashes: "/eth/v1.2/blockscout/receipts/by-transaction-hash",
    logs_search: "/eth/v1.2/blockscout/logs/search",
    state_balances: "/eth/v1.2/blockscout/state/balances",
    state_nonces: "/eth/v1.2/blockscout/state/nonces",
    state_codes: "/eth/v1.2/blockscout/state/codes"
  ]

  @core_api_endpoints [
    chain_info: "/eth/v1.2/metadata",
    block_last: "/eth/v1.2/block/last",
    blocks_query: "/eth/v1.2/block",
    transactions_query: "/eth/v1.2/transaction",
    transaction_results_batch: "/eth/v1.2/transactionResult/batch",
    account_query: "/eth/v1.2/account",
    code_by_hash: "/eth/v1.2/code"
  ]

  @defaults [
    http_client: Explorer.HttpClient,
    profile: :private_explorer_api,
    base_url: nil,
    bearer_token: nil,
    recv_timeout: :timer.seconds(30),
    connect_timeout: :timer.seconds(5),
    endpoints: []
  ]

  @spec get(keyword()) :: keyword()
  def get(opts \\ []) do
    app_config = deep_merge(@defaults, Application.get_env(:explorer, Explorer.ChainData.STRATO, []))

    overrides = Keyword.get(opts, :strato, [])

    app_config
    |> normalize_profile()
    |> with_profile_endpoints()
    |> deep_merge(overrides)
    |> normalize_profile()
  end

  @spec endpoint(atom(), keyword()) :: String.t()
  def endpoint(name, config) do
    config
    |> Keyword.get(:endpoints, [])
    |> Keyword.fetch!(name)
  end

  @spec profile(keyword()) :: :private_explorer_api | :core_api
  def profile(config) do
    config
    |> Keyword.get(:profile, :private_explorer_api)
    |> normalize_profile_value()
  end

  defp with_profile_endpoints(config) do
    deep_merge(config, endpoints: default_endpoints(profile(config)))
  end

  defp default_endpoints(:core_api), do: @core_api_endpoints
  defp default_endpoints(:private_explorer_api), do: @private_explorer_api_endpoints

  defp normalize_profile(config) do
    Keyword.update(config, :profile, :private_explorer_api, &normalize_profile_value/1)
  end

  defp normalize_profile_value("core_api"), do: :core_api
  defp normalize_profile_value("private_explorer_api"), do: :private_explorer_api
  defp normalize_profile_value(:core_api), do: :core_api
  defp normalize_profile_value(_value), do: :private_explorer_api

  defp deep_merge(base, overrides) do
    Keyword.merge(base, overrides, fn
      :endpoints, left, right ->
        Keyword.merge(left, right)

      _key, _left, right ->
        right
    end)
  end
end

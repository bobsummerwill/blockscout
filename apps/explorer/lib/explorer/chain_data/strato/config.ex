defmodule Explorer.ChainData.STRATO.Config do
  @moduledoc false

  @defaults [
    http_client: Explorer.HttpClient,
    base_url: nil,
    recv_timeout: :timer.seconds(30),
    connect_timeout: :timer.seconds(5),
    endpoints: []
  ]

  @spec get(keyword()) :: keyword()
  def get(opts \\ []) do
    app_config =
      deep_merge(@defaults, Application.get_env(:explorer, Explorer.ChainData.STRATO, []))

    overrides = Keyword.get(opts, :strato, [])

    deep_merge(app_config, overrides)
  end

  @spec endpoint(atom(), keyword()) :: String.t()
  def endpoint(name, config) do
    config
    |> Keyword.get(:endpoints, [])
    |> Keyword.fetch!(name)
  end

  defp deep_merge(base, overrides) do
    Keyword.merge(base, overrides, fn
      :endpoints, left, right ->
        Keyword.merge(left, right)

      _key, _left, right ->
        right
    end)
  end
end

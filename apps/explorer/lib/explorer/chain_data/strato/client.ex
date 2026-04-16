defmodule Explorer.ChainData.STRATO.Client do
  @moduledoc false

  alias Explorer.ChainData.STRATO.Config

  @type response :: {:ok, map() | list() | nil} | {:error, term()}

  @spec get(String.t(), keyword()) :: response()
  def get(path, opts \\ []) do
    request(:get, path, nil, opts)
  end

  @spec post(String.t(), map(), keyword()) :: response()
  def post(path, body, opts \\ []) do
    request(:post, path, body, opts)
  end

  @spec request(atom(), String.t(), map() | nil, keyword()) :: response()
  def request(method, path, body, opts \\ []) do
    config = Config.get(opts)

    with {:ok, url} <- build_url(config, path),
         {:ok, response} <- perform_request(method, url, body, config, opts) do
      decode_response({:ok, response})
    end
  end

  defp build_url(config, path) do
    case Keyword.get(config, :base_url) do
      nil ->
        {:error, :strato_base_url_not_configured}

      base_url when is_binary(base_url) ->
        {:ok, join_url(base_url, path)}
    end
  end

  defp join_url(base_url, path) do
    base_url = String.trim_trailing(base_url, "/")
    path = if String.starts_with?(path, "/"), do: path, else: "/" <> path

    base_url <> path
  end

  defp perform_request(method, url, body, config, opts) do
    http_client = Keyword.fetch!(config, :http_client)
    query = Keyword.get(opts, :params, [])

    headers =
      [{"accept", "application/json"}, {"user-agent", "curl/8.0 (Blockscout STRATO client)"}]
      |> maybe_put_authorization(config)
      |> maybe_put_content_type(body)

    request_opts = [
      recv_timeout: Keyword.get(config, :recv_timeout),
      timeout: Keyword.get(config, :connect_timeout),
      params: query
    ]

    method
    |> http_client.request(url, headers, encode_body(body), request_opts)
    |> normalize_response()
  end

  defp normalize_response({:ok, _response} = response), do: response
  defp normalize_response({:error, _reason} = response), do: response
  defp normalize_response(%{status_code: _status_code} = response), do: {:ok, response}
  defp normalize_response(other), do: other

  defp maybe_put_authorization(headers, config) do
    case Keyword.get(config, :bearer_token) do
      token when is_binary(token) and token != "" ->
        [{"authorization", "Bearer #{token}"} | headers]

      _other ->
        headers
    end
  end

  defp maybe_put_content_type(headers, nil), do: headers
  defp maybe_put_content_type(headers, _body), do: [{"content-type", "application/json"} | headers]

  defp encode_body(nil), do: nil
  defp encode_body(body), do: Jason.encode!(body)

  defp decode_response({:ok, %{status_code: status_code, body: body}})
       when status_code >= 200 and status_code < 300 do
    decode_body(body)
  end

  defp decode_response({:ok, %{status_code: status_code, body: body}}) do
    {:error, {:http_error, status_code, decode_body_or_raw(body)}}
  end

  defp decode_response(other), do: other

  defp decode_body(nil), do: {:ok, nil}
  defp decode_body(""), do: {:ok, nil}
  defp decode_body(body) when is_map(body) or is_list(body), do: {:ok, body}

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _reason} -> {:ok, %{"raw_body" => body}}
    end
  end

  defp decode_body_or_raw(nil), do: nil
  defp decode_body_or_raw(body) when is_map(body) or is_list(body), do: body

  defp decode_body_or_raw(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _reason} -> body
    end
  end
end

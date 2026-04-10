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
      decode_response(response)
    end
  end

  defp build_url(config, path) do
    case Keyword.get(config, :base_url) do
      nil ->
        {:error, :strato_base_url_not_configured}

      base_url when is_binary(base_url) ->
        {:ok, URI.merge(base_url, path) |> to_string()}
    end
  end

  defp perform_request(method, url, body, config, opts) do
    http_client = Keyword.fetch!(config, :http_client)
    query = Keyword.get(opts, :params, [])

    headers =
      [{"accept", "application/json"}]
      |> maybe_put_content_type(body)

    request_opts = [
      recv_timeout: Keyword.get(config, :recv_timeout),
      timeout: Keyword.get(config, :connect_timeout),
      params: query
    ]

    http_client.request(method, url, headers, encode_body(body), request_opts)
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

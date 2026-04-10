defmodule Explorer.ChainData.STRATO.State do
  @moduledoc false

  alias Explorer.ChainData.{
    Balance,
    Code,
    Nonce
  }

  alias Explorer.ChainData.STRATO.{Client, Config, Mapper}

  @spec balances([Balance.Request.t()], keyword()) :: {:ok, Balance.Batch.t()} | {:error, term()}
  def balances(requests, opts) do
    request(:state_balances, requests, opts, "balances", &Mapper.balance_batch/1)
  end

  @spec nonces([Nonce.Request.t()], keyword()) :: {:ok, Nonce.Batch.t()} | {:error, term()}
  def nonces(requests, opts) do
    request(:state_nonces, requests, opts, "nonces", &Mapper.nonce_batch/1)
  end

  @spec codes([Code.Request.t()], keyword()) :: {:ok, Code.Batch.t()} | {:error, term()}
  def codes(requests, opts) do
    config = Config.get(opts)

    case Config.profile(config) do
      :core_api ->
        {:ok,
         %Code.Batch{
           errors:
             Enum.map(requests, fn request ->
               %{request: request, reason: :unsupported_by_strato_core_api}
             end)
         }}

      :private_explorer_api ->
        request(:state_codes, requests, opts, "codes", &Mapper.code_batch/1)
    end
  end

  defp request(endpoint, requests, opts, key, mapper) do
    config = Config.get(opts)

    case Config.profile(config) do
      :core_api ->
        request_core_api(requests, opts, key, mapper, config)

      :private_explorer_api ->
        with {:ok, payload} <-
               Client.post(
                Config.endpoint(endpoint, config),
                %{requests: Enum.map(requests, &request_to_map/1)},
                opts
               ) do
          {:ok, mapper.(payload)}
        end
    end
  end

  defp request_core_api(requests, opts, key, mapper, config) do
    requests
    |> Enum.reduce_while({:ok, []}, fn request, {:ok, values} ->
      params = [address: request.address_hash, maxnumber: request.block_number]

      case Client.get(Config.endpoint(:account_query, config), Keyword.put(opts, :params, params)) do
        {:ok, payload} ->
          value =
            payload
            |> List.wrap()
            |> List.first()

          {:cont, {:ok, [value | values]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, values} ->
        {:ok, mapper.(%{key => Enum.reverse(values)})}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request_to_map(%Balance.Request{} = request) do
    %{address_hash: request.address_hash, block_number: request.block_number}
  end

  defp request_to_map(%Nonce.Request{} = request) do
    %{address_hash: request.address_hash, block_number: request.block_number}
  end

  defp request_to_map(%Code.Request{} = request) do
    %{address_hash: request.address_hash, block_number: request.block_number}
  end
end

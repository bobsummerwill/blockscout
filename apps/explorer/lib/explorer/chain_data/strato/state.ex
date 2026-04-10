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
    request(:state_balances, requests, opts, &Mapper.balance_batch/1)
  end

  @spec nonces([Nonce.Request.t()], keyword()) :: {:ok, Nonce.Batch.t()} | {:error, term()}
  def nonces(requests, opts) do
    request(:state_nonces, requests, opts, &Mapper.nonce_batch/1)
  end

  @spec codes([Code.Request.t()], keyword()) :: {:ok, Code.Batch.t()} | {:error, term()}
  def codes(requests, opts) do
    request(:state_codes, requests, opts, &Mapper.code_batch/1)
  end

  defp request(endpoint, requests, opts, mapper) do
    config = Config.get(opts)

    with {:ok, payload} <-
           Client.post(
             Config.endpoint(endpoint, config),
             %{requests: Enum.map(requests, &request_to_map/1)},
             opts
           ) do
      {:ok, mapper.(payload)}
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

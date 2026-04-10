defmodule Explorer.Migrator.RefetchContractCodes do
  @moduledoc """
  Refetch contract_code for. Migration created for running on zksync chain type.
  It has an issue with created contract code derived from internal transactions. Such codes are not correct.
  So, this migration fetches for all current smart contracts actual bytecode from the JSON RPC node.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.{Address, Data, Import}
  alias Explorer.ChainData.{Backend, Code}
  alias Explorer.Chain.Hash.Address, as: AddressHash
  alias Explorer.Chain.Import.Runner.Addresses
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  require Logger

  @migration_name "refetch_contract_codes"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([address], address.hash)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    Address
    |> where([address], not is_nil(address.contract_code) and not address.contract_code_refetched)
  end

  @impl FillingMigration
  def update_batch(address_hashes) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    address_hashes
    |> Enum.map(&address_to_fetch_code_request/1)
    |> Backend.codes_at(json_rpc_named_arguments: json_rpc_named_arguments)
    |> case do
      {:ok, %Code.Batch{codes: codes}} ->
        addresses_params = codes |> Enum.map(&code_to_address/1) |> Enum.sort_by(& &1.hash)

        Addresses.insert(Repo, addresses_params, %{
          timeout: :infinity,
          on_conflict: {:replace, [:contract_code, :contract_code_refetched, :updated_at]},
          timestamps: Import.timestamps()
        })

      {:error, reason} ->
        Logger.error(fn -> ["failed to fetch contract codes: ", inspect(reason)] end,
          error_count: Enum.count(address_hashes)
        )
    end
  end

  @impl FillingMigration
  def update_cache, do: :ok

  defp address_to_fetch_code_request(address_hash) do
    %Code.Request{block_number: "latest", address_hash: to_string(address_hash)}
  end

  defp code_to_address(%Code{value: bytecode, address_hash: address_hash}) do
    {:ok, address_hash} = AddressHash.cast(address_hash)
    {:ok, bytecode} = Data.cast(bytecode)
    %{hash: address_hash, contract_code: bytecode, contract_code_refetched: true}
  end
end

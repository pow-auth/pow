defmodule PowPersistentSession.Store.PersistentSessionCache do
  @moduledoc false
  use Pow.Store.Base,
    ttl: :timer.hours(24) * 30,
    namespace: "persistent_session"

  alias Pow.{Operations, Store.Base}

  @impl true
  @spec put(Base.config(), binary(), {map(), list()}) :: :ok
  def put(config, id, {user, metadata}) do
    Base.put(config, backend_config(config), {id, {user, metadata}})
  end

  @impl true
  @spec get(Base.config(), binary()) :: {map(), list()} | nil | :not_found
  def get(config, id) do
    config
    |> Base.get(backend_config(config), id)
    |> convert_old_value()
    |> reload(config)
  end

  # TODO: Remove by 1.1.0
  defp convert_old_value(:not_found), do: :not_found
  defp convert_old_value({user, metadata}), do: {user, metadata}
  defp convert_old_value(clauses) when is_list(clauses), do: {clauses, []}

  defp reload(:not_found, _config), do: :not_found
  defp reload(value, config) do
    case Keyword.has_key?(config, :pow_config) do
      true ->
        do_reload(value, config)

      # TODO: Remove by 1.1.0
      false ->
        IO.warn("#{inspect __MODULE__}.get/2 call without `:pow_config` in second argument is deprecated, find the migration step in the changelog.")

        value
    end
  end

  # TODO: Remove by 1.1.0
  defp do_reload({clauses, metadata}, config) when is_list(clauses) do
    pow_config = fetch_pow_config!(config)

    case Operations.get_by(clauses, pow_config) do
      nil  -> nil
      user -> {user, metadata}
    end
  end
  defp do_reload({user, metadata}, config) do
    pow_config = fetch_pow_config!(config)

    case Operations.reload(user, pow_config) do
      nil  -> nil
      user -> {user, metadata}
    end
  end

  defp fetch_pow_config!(config), do: Keyword.get(config, :pow_config) || raise "No `:pow_config` value found in the store config."
end

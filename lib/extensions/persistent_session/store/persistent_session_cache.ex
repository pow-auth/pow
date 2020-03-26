defmodule PowPersistentSession.Store.PersistentSessionCache do
  @moduledoc false
  use Pow.Store.Base,
    ttl: :timer.hours(24) * 30,
    namespace: "persistent_session"

  alias Pow.Store.Base

  # TODO: Remove by 1.1.0
  @impl true
  def get(config, id) do
    config
    |> Base.get(backend_config(config), id)
    |> convert_old_value()
  end

  defp convert_old_value(:not_found), do: :not_found
  defp convert_old_value({user, metadata}), do: {user, metadata}
  defp convert_old_value(clauses) when is_list(clauses), do: {clauses, []}
end

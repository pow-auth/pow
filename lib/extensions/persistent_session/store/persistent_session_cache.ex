defmodule PowPersistentSession.Store.PersistentSessionCache do
  @moduledoc false
  use Pow.Store.Base,
    ttl: :timer.hours(24) * 30,
    namespace: "persistent_session"

  alias Pow.{Operations, Store.Base}

  @impl true
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
  # TODO: Remove by 1.1.0
  defp reload({clauses, metadata}, config) when is_list(clauses) do
    pow_config = Keyword.get(config, :pow_config)

    case Operations.get_by(clauses, pow_config) do
      nil  -> nil
      user -> {user, metadata}
    end
  end
  defp reload({user, metadata}, config) do
    pow_config = Keyword.get(config, :pow_config)

    case Operations.reload(user, pow_config) do
      nil  -> nil
      user -> {user, metadata}
    end
  end
end

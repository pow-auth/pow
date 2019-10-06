defmodule PowRateLimiter.Plug do
  @moduledoc """
  Plug helper methods.
  """
  alias Plug.Conn
  alias Pow.{Config, Plug}
  alias PowRateLimiter.Engine.Ets

  @doc """
  Increases the rate record and checks if the count has been reached.
  """
  @spec increase_rate_check(Conn.t()) :: :allow | :deny
  def increase_rate_check(conn) do
    config                  = Plug.fetch_config(conn)
    user_id                 = get_user_id_value(config, conn)
    {engine, engine_config} = rate_limiter(config)

    case engine.increase_rate_check(engine_config, conn, user_id) do
      {:allow, _} -> :allow
      {:deny, _}  -> :deny
    end
  end

  @doc """
  Clears the current rate record.
  """
  @spec clear_rate(Conn.t()) :: :ok
  def clear_rate(conn) do
    config                  = Plug.fetch_config(conn)
    user_id                 = get_user_id_value(config, conn)
    {engine, engine_config} = rate_limiter(config)

    engine.clear_rate(engine_config, conn, user_id)
  end

  defp get_user_id_value(config, conn) do
    user_mod      = Config.user!(config)
    user_id_field = user_mod.pow_user_id_field()

    conn.params
    |> Map.get("user", %{})
    |> Map.fetch!(Atom.to_string(user_id_field))
    |> Base.url_encode64(padding: false)
  end

  defp rate_limiter(config) do
    case Config.get(config, :pow_rate_limiter_module, default_engine(config)) do
      {engine, engine_config} -> {engine, engine_config}
      engine                  -> {engine, []}
    end
  end

  defp default_engine(_config), do: {Ets, []}
end

defmodule PowRateLimiter.Phoenix.ControllerCallbacks do
  @moduledoc """
  Controller callback logic for rate limiting.
  """
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias PowRateLimiter.Plug

  @doc false
  @impl true
  def before_process(Pow.Phoenix.SessionController, :create, conn, _config) do
    case Plug.increase_rate_check(conn) do
      :allow -> conn
      :deny  -> halt_rate_limited(conn)
    end
  end

  defp halt_rate_limited(conn) do
    error = extension_messages(conn).rate_limited(conn)
    conn  =
      conn
      |> Phoenix.Controller.put_flash(:error, error)
      |> Phoenix.Controller.redirect(to: routes(conn).session_path(conn, :new))

    {:halt, conn}
  end

  @doc false
  @impl true
  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, _config) do
    Plug.clear_rate(conn)

    {:ok, conn}
  end
end

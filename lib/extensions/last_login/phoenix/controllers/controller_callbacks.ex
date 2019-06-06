defmodule PowLastLogin.Phoenix.ControllerCallbacks do
  @moduledoc false
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Pow.Plug
  alias PowLastLogin.Ecto.Context

  @impl true
  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, config) do
    conn
    |> Plug.current_user()
    |> update_last_login(conn, config)
  end

  defp update_last_login(user, conn, config) do
    remote_ip =
      conn.remote_ip
      |> :inet_parse.ntoa
      |> to_string()

    user
    |> Context.update_last_login(remote_ip, config)
    |> case do
      {:error, _changeset} -> {:error, conn}
      {:ok, user}          -> {:ok, maybe_renew_conn(conn, user, config)}
    end
  end

  defp maybe_renew_conn(conn, %{id: user_id} = user, config) do
    case Plug.current_user(conn, config) do
      %{id: ^user_id} -> Plug.get_plug(config).do_create(conn, user, config)
      _any            -> conn
    end
  end
end

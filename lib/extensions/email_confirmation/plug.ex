defmodule PowEmailConfirmation.Plug do
  @moduledoc false
  alias Pow.Plug
  alias PowEmailConfirmation.Ecto.Context

  @spec confirm_email(Conn.t(), binary()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()} | no_return
  def confirm_email(conn, token) do
    config = Plug.fetch_config(conn)

    config
    |> Context.get_by_confirmation_token(token)
    |> maybe_confirm_email(conn, config)
  end

  defp maybe_confirm_email(nil, conn, _config) do
    {:error, nil, conn}
  end
  defp maybe_confirm_email(user, conn, config) do
    config
    |> Context.confirm_email(user)
    |> case do
      {:error, changeset} -> {:error, changeset, conn}
      {:ok, user}         -> {:ok, user, maybe_renew_conn(conn, user, config)}
    end
  end

  defp maybe_renew_conn(conn, %{id: user_id} = user, config) do
    mod = config[:mod]

    case Plug.current_user(conn) do
      %{id: ^user_id} -> mod.do_create(conn, user)
      _any            -> conn
    end
  end
end

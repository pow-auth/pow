defmodule PowEmailConfirmation.Plug do
  @moduledoc false
  alias Plug.Conn
  alias Pow.Plug
  alias PowEmailConfirmation.Ecto.Context

  @spec confirm_email(Conn.t(), binary()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def confirm_email(conn, token) do
    config = Plug.fetch_config(conn)

    token
    |> Context.get_by_confirmation_token(config)
    |> maybe_confirm_email(conn, config)
  end

  defp maybe_confirm_email(nil, conn, _config) do
    {:error, nil, conn}
  end
  defp maybe_confirm_email(user, conn, config) do
    user
    |> Context.confirm_email(config)
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

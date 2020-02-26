defmodule PowEmailConfirmation.Plug do
  @moduledoc """
  Plug helper methods.
  """
  alias Plug.Conn
  alias Pow.{Operations, Plug}
  alias PowEmailConfirmation.Ecto.Context

  @doc """
  Check if the there is a pending email change for the current user.
  """
  @spec pending_email_change?(Conn.t()) :: boolean()
  def pending_email_change?(conn) do
    config = Plug.fetch_config(conn)

    conn
    |> Plug.current_user()
    |> Context.pending_email_change?(config)
  end

  @doc """
  Check if the email for the current user is yet to be confirmed.
  """
  @spec email_unconfirmed?(Conn.t()) :: boolean()
  def email_unconfirmed?(conn) do
    config = Plug.fetch_config(conn)

    conn
    |> Plug.current_user()
    |> Context.current_email_unconfirmed?(config)
  end

  @doc """
  Confirms the e-mail for the user found by the provided confirmation token.

  If successful, and a session exists, the session will be regenerated.
  """
  @spec confirm_email(Conn.t(), binary()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def confirm_email(conn, token) do
    config = Plug.fetch_config(conn)

    token
    |> Context.get_by_confirmation_token(config)
    |> maybe_confirm_email(conn, config)
  end

  @spec refreshed_user_with_confirmation_token(Conn.t()) :: any()
  def refreshed_user_with_confirmation_token(conn) do
    refreshed_user = conn
      |> Plug.refresh_current_user()
      |> Plug.current_user()

      case Context.ensure_confirmation_token(refreshed_user, Plug.fetch_config(conn)) do
        {:ok, maybe_updated_user} -> maybe_updated_user
        {:error, _changeset} -> refreshed_user
      end
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

  defp maybe_renew_conn(conn, user, config) do
    case equal_user?(user, Plug.current_user(conn, config), config) do
      true  -> Plug.create(conn, user, config)
      false -> conn
    end
  end

  defp equal_user?(_user, nil, _config), do: false
  defp equal_user?(user, current_user, config) do
    {:ok, clauses1} = Operations.fetch_primary_key_values(user, config)
    {:ok, clauses2} = Operations.fetch_primary_key_values(current_user, config)

    Keyword.equal?(clauses1, clauses2)
  end
end

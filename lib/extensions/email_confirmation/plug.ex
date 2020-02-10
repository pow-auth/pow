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
  Signs the e-mail confirmation token for public consumption.

  The token will be signed using `Pow.Plug.sign_token/4`.
  """
  @spec sign_confirmation_token(Conn.t(), map()) :: binary()
  def sign_confirmation_token(conn, %{email_confirmation_token: token}),
    do: Plug.sign_token(conn, signing_salt(), token)

  defp signing_salt(), do: Atom.to_string(__MODULE__)

  @doc """
  Verifies the token and confirms the e-mail for the user found with it.

  If successful, and a session exists, the session will be regenerated.

  The token should have been signed with `sign_confirmation_token/2`. The token
  will be decoded and verified with `Pow.Plug.verify_token/4`.
  """
  @spec confirm_email_by_token(Conn.t(), binary()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def confirm_email_by_token(conn, signed_token) do
    config = Plug.fetch_config(conn)

    conn
    |> verify_and_get_by_token(signed_token, config)
    |> maybe_confirm_email(conn, config)
  end

  defp verify_and_get_by_token(conn, signed_token, config) do
    case Plug.verify_token(conn, signing_salt(), signed_token, config) do
      :error       -> nil
      {:ok, token} -> Context.get_by_confirmation_token(token, config)
    end
  end

  defp maybe_confirm_email(nil, conn, _config), do: {:error, nil, conn}
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

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `confirm_email_by_token/2`"
  def confirm_email(conn, token) do
    config = Plug.fetch_config(conn)

    token
    |> Context.get_by_confirmation_token(config)
    |> maybe_confirm_email(conn, config)
  end
end

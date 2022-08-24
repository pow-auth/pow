defmodule PowEmailConfirmation.Plug do
  @moduledoc """
  Plug helper functions.
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
  Verifies the signed token and fetches user.

  If a user is found, it'll be assigned to `conn.assigns` for key
  `:confirm_email_user`.

  The token should have been signed with `sign_confirmation_token/2`. The token
  will be decoded and verified with `Pow.Plug.verify_token/4`.
  """
  @spec load_user_by_token(Conn.t(), binary()) :: {:ok, Conn.t()} | {:error, Conn.t()}
  def load_user_by_token(conn, signed_token) do
    config = Plug.fetch_config(conn)

    with {:ok, token}               <- Plug.verify_token(conn, signing_salt(), signed_token, config),
         user when not is_nil(user) <- Context.get_by_confirmation_token(token, config) do
      {:ok, Conn.assign(conn, :confirm_email_user, user)}
    else
      _any -> {:error, conn}
    end
  end

  @doc """
  Confirms the e-mail for the user.

  Expects user to exist in `conn.assigns` for key `:confirm_email_user`.

  If successful, and a session exists, the session will be regenerated.
  """
  @spec confirm_email(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def confirm_email(conn, params) when is_map(params) do
    config = Plug.fetch_config(conn)

    conn
    |> confirm_email_user()
    |> Context.confirm_email(params, config)
    |> case do
      {:error, changeset} -> {:error, changeset, conn}
      {:ok, user}         -> {:ok, user, maybe_renew_conn(conn, user, config)}
    end
  end
  # TODO: Remove by 1.1.0
  def confirm_email(conn, token) when is_binary(token) do
    IO.warn "#{unquote(__MODULE__)}.confirm_email/2 called with token is deprecated, use `load_user_by_token/2` and `confirm_email/2` with map as second argument instead"

    config = Plug.fetch_config(conn)

    token
    |> Context.get_by_confirmation_token(config)
    |> maybe_confirm_email(conn, config)
  end

  defp confirm_email_user(conn) do
    conn.assigns[:confirm_email_user]
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
  defp maybe_confirm_email(nil, conn, _config), do: {:error, nil, conn}
  defp maybe_confirm_email(user, conn, config) do
    user
    |> Context.confirm_email(%{}, config)
    |> case do
      {:error, changeset} -> {:error, changeset, conn}
      {:ok, user}         -> {:ok, user, maybe_renew_conn(conn, user, config)}
    end
  end
end

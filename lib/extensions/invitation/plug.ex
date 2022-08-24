defmodule PowInvitation.Plug do
  @moduledoc """
  Plug helper functions.
  """
  alias Plug.Conn
  alias Pow.{Config, Plug}
  alias PowInvitation.Ecto.Context, as: InvitationContext
  alias PowInvitation.Ecto.Schema

  @doc """
  Creates a new invited user by the current user in the connection.
  """
  @spec create_user(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def create_user(conn, params) do
    config = Plug.fetch_config(conn)

    conn
    |> Plug.current_user()
    |> InvitationContext.create(params, config)
    |> case do
      {:ok, user}         -> {:ok, user, conn}
      {:error, changeset} -> {:error, changeset, conn}
    end
  end

  @doc """
  Creates a changeset from the user fetched in the connection.
  """
  @spec change_user(Conn.t(), map()) :: map()
  def change_user(conn, params \\ %{}) do
    conn
    |> invited_user()
    |> Kernel.||(user_struct(conn))
    |> Schema.accept_invitation_changeset(params)
  end

  defp user_struct(conn) do
    conn
    |> Plug.fetch_config()
    |> Config.user!()
    |> struct()
  end

  @doc """
  Updates current user in the connection with the params.

  Expects the invited user to exist in `conn.assigns` for key
  `:invited_user`.

  If successful the session will be regenerated.
  """
  @spec update_user(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def update_user(conn, params) do
    config = Plug.fetch_config(conn)

    conn
    |> invited_user()
    |> InvitationContext.update(params, config)
    |> case do
      {:ok, user}         -> {:ok, user, Plug.create(conn, user, config)}
      {:error, changeset} -> {:error, changeset, conn}
    end
  end

  defp invited_user(conn), do: conn.assigns[:invited_user]

  @doc """
  Signs the invitation token for public consumption.

  The token will be signed using `Pow.Plug.sign_token/4`.
  """
  @spec sign_invitation_token(Conn.t(), map()) :: binary()
  def sign_invitation_token(conn, %{invitation_token: token}),
    do: Plug.sign_token(conn, signing_salt(), token)

  defp signing_salt(), do: Atom.to_string(__MODULE__)

  @doc """
  Verifies the signed token and fetches invited user.

  If a user is found, it'll be assigned to `conn.assigns` for key
  `:invited_user`.

  The token should have been signed with `sign_invitation_token/2`. The token
  will be decoded and verified with `Pow.Plug.verify_token/4`.
  """
  @spec load_invited_user_by_token(Conn.t(), binary()) :: {:ok, Conn.t()} | {:error, Conn.t()}
  def load_invited_user_by_token(conn, signed_token) do
    config = Plug.fetch_config(conn)

    with {:ok, token}               <- Plug.verify_token(conn, signing_salt(), signed_token, config),
         user when not is_nil(user) <- InvitationContext.get_by_invitation_token(token, config) do
      {:ok, Conn.assign(conn, :invited_user, user)}
    else
      _any -> {:error, conn}
    end
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `load_invited_user_by_token/2` instead"
  def invited_user_from_token(conn, token) do
    config = Plug.fetch_config(conn)

    InvitationContext.get_by_invitation_token(token, config)
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "No longer used"
  def assign_invited_user(conn, user) do
    Conn.assign(conn, :invited_user, user)
  end
end

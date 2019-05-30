defmodule PowInvitation.Plug do
  @moduledoc """
  Plug helper methods.
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

  If successful the session will be regenerated.
  """
  @spec update_user(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def update_user(conn, params) do
    config = Plug.fetch_config(conn)

    conn
    |> invited_user()
    |> InvitationContext.update(params, config)
    |> case do
      {:ok, user}         -> {:ok, user, Plug.get_plug(config).do_create(conn, user, config)}
      {:error, changeset} -> {:error, changeset, conn}
    end
  end

  defp invited_user(conn), do: conn.assigns[:invited_user]

  @doc """
  Fetches invited user by the invitation token.
  """
  @spec invited_user_from_token(Conn.t(), binary()) :: map() | nil
  def invited_user_from_token(conn, token) do
    config = Plug.fetch_config(conn)

    InvitationContext.get_by_invitation_token(token, config)
  end

  @doc """
  Assigns a `:invited_user` key with the user in the connection.
  """
  @spec assign_invited_user(Conn.t(), map()) :: Conn.t()
  def assign_invited_user(conn, user) do
    Conn.assign(conn, :invited_user, user)
  end
end

defmodule Authex.Plug.RequireNotAuthenticated do
  @moduledoc """
  This plug ensures that a user hasn't already been authenticated.

  Example:

    plug Authex.Plug.Session,
      current_user_assigns_key: :current_user
    plug Authex.Plug.RequireAuthenticated,
      error_handler: Authex.Phoenix.ErrorHandler
  """
  alias Plug.Conn
  alias Authex.{Plug, Phoenix.ErrorHandler}

  @spec init(Keyword.t()) :: Keyword.t()
  def init(opts), do: opts

  @spec call(Conn.t(), Keyword.t()) :: Conn.t()
  def call(conn, opts) do
    conn
    |> Plug.current_user()
    |> maybe_halt(conn, opts)
  end

  defp maybe_halt(nil, conn, _opts), do: conn
  defp maybe_halt(_user, conn, opts) do
    handler = Keyword.get(opts, :error_handler, ErrorHandler)

    conn
    |> handler.call(:already_authenticated)
    |> Conn.halt()
  end
end

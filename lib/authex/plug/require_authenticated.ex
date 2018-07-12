defmodule Authex.Plug.RequireAuthenticated do
  @moduledoc """
  This plug ensures that a user has been authenticated.

  Example:

    plug Authex.Plug.Session,
      current_user_assigns_key: :current_user
    plug Authex.Plug.RequireAuthenticated,
      error_handler: Authex.Phoenix.ErrorHandler
  """
  alias Plug.Conn
  alias Authex.{Plug, Phoenix.ErrorHandler}

  @spec init(Keyword.t()) :: nil
  def init(opts), do: opts

  @spec call(Conn.t(), Keyword.t()) :: Conn.t()
  def call(conn, opts) do
    conn
    |> Plug.current_user()
    |> maybe_halt(conn, opts)
  end

  defp maybe_halt(nil, conn, opts) do
    handler = Keyword.get(opts, :error_handler, ErrorHandler)

    conn
    |> handler.call(:not_authenticated)
    |> Conn.halt()
  end
  defp maybe_halt(_user, conn, _opts), do: conn
end

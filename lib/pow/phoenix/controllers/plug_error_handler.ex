defmodule Pow.Phoenix.PlugErrorHandler do
  @moduledoc """
  Used with Pow.Plug.RequireAuthenticated or Pow.Plug.RequireNotAuthenticated.
  """
  alias Phoenix.Controller
  alias Plug.Conn
  alias Pow.Phoenix.Controller, as: PowController

  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, :not_authenticated) do
    conn
    |> Controller.put_flash(:error, PowController.messages(conn).user_not_authenticated(conn))
    |> Controller.redirect(to: PowController.routes(conn).user_not_authenticated_path(conn))
  end
  def call(conn, :already_authenticated) do
    conn
    |> Controller.put_flash(:error, PowController.messages(conn).user_already_authenticated(conn))
    |> Controller.redirect(to: PowController.routes(conn).user_already_authenticated_path(conn))
  end
end

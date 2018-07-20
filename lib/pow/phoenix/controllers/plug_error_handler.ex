defmodule Pow.Phoenix.PlugErrorHandler do
  @moduledoc """
  Used with Pow.Plug.RequireAuthenticated or Pow.Plug.RequireNotAuthenticated.
  """
  alias Phoenix.Controller
  alias Plug.Conn

  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, :not_authenticated) do
    conn
    |> Controller.put_flash(:error, "You're not authenticated.")
    |> Controller.redirect(to: "/")
  end
  def call(conn, :already_authenticated) do
    conn
    |> Controller.put_flash(:error, "You're already authenticated.")
    |> Controller.redirect(to: "/")
  end
end

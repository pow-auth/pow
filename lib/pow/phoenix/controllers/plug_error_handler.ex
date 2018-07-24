defmodule Pow.Phoenix.PlugErrorHandler do
  @moduledoc """
  Used with `Pow.Plug.RequireAuthenticated` and
  `Pow.Plug.RequireNotAuthenticated`.
  """
  alias Phoenix.Controller
  alias Plug.Conn
  alias Pow.Phoenix.{Messages, Routes}

  import Pow.Phoenix.Controller, only: [messages: 2, routes: 2]

  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, :not_authenticated) do
    conn
    |> Controller.put_flash(:error, messages(conn, Messages).user_not_authenticated(conn))
    |> Controller.redirect(to: routes(conn, Routes).user_not_authenticated_path(conn))
  end
  def call(conn, :already_authenticated) do
    conn
    |> Controller.put_flash(:error, messages(conn, Messages).user_already_authenticated(conn))
    |> Controller.redirect(to: routes(conn, Routes).user_already_authenticated_path(conn))
  end
end

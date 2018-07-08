defmodule Authex.Phoenix.ErrorHandler do
  @moduledoc """
  Defines default handling of errors.
  """
  alias Plug.Conn
  alias Phoenix.Controller

  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, :not_authenticated) do
    conn
    |> Controller.put_flash(:error, "You're not authenticated")
    |> Controller.redirect(to: "/")
  end
  def call(conn, :already_authenticated) do
    conn
    |> Controller.put_flash(:error, "You're already authenticated")
    |> Controller.redirect(to: "/")
  end
end

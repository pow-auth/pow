defmodule Pow.Phoenix.PlugErrorHandler do
  @moduledoc """
  Used with `Pow.Plug.RequireAuthenticated` and
  `Pow.Plug.RequireNotAuthenticated`.
  """
  alias Phoenix.Controller
  alias Plug.Conn
  alias Pow.Phoenix.{Messages, Routes}

  import Pow.Phoenix.Controller, only: [messages: 2, routes: 2]

  @doc """
  Redirect user and add error flash message.

  For `:not_authenticated` calls, the flash message defaults to
  `Pow.Phoenix.Messages.user_not_authenticated/1` and the user is redirected to
  `Pow.Phoenix.Routes.user_not_authenticated_path/1`.

  For `:already_authenticated` calls, the flash message defaults to
  `Pow.Phoenix.Messages.user_already_authenticated/1` and the user is redirected to
  `Pow.Phoenix.Routes.user_already_authenticated_path/1`.
  """
  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, :not_authenticated) do
    conn
    |> maybe_set_error_flash(messages(conn, Messages).user_not_authenticated(conn))
    |> Controller.redirect(to: routes(conn, Routes).user_not_authenticated_path(conn))
  end
  def call(conn, :already_authenticated) do
    conn
    |> maybe_set_error_flash(messages(conn, Messages).user_already_authenticated(conn))
    |> Controller.redirect(to: routes(conn, Routes).user_already_authenticated_path(conn))
  end

  defp maybe_set_error_flash(conn, nil), do: conn
  defp maybe_set_error_flash(conn, error), do: Controller.put_flash(conn, :error, error)
end

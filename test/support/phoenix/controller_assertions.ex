defmodule Pow.Test.Phoenix.ControllerAssertions do
  @moduledoc false
  alias Phoenix.ConnTest
  alias Pow.Phoenix.{Messages, Routes}

  @spec assert_authenticated_redirect(Plug.Conn.t()) :: no_return
  defmacro assert_authenticated_redirect(conn) do
    quote do
      routes = Keyword.get(unquote(conn).private.pow_config, :routes_backend, Routes)

      assert ConnTest.redirected_to(unquote(conn)) == routes.after_sign_in_path(unquote(conn))
      assert ConnTest.get_flash(unquote(conn), :error) == Messages.user_already_authenticated(unquote(conn))
    end
  end

  @spec assert_not_authenticated_redirect(Plug.Conn.t()) :: no_return
  defmacro assert_not_authenticated_redirect(conn) do
    quote do
      router = Module.concat([unquote(conn).private.phoenix_router, Helpers])

      assert ConnTest.redirected_to(unquote(conn)) == router.pow_session_path(unquote(conn), :new, request_path: Phoenix.Controller.current_path(unquote(conn)))
      assert ConnTest.get_flash(unquote(conn), :error) == Messages.user_not_authenticated(unquote(conn))
    end
  end
end

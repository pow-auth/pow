defmodule Pow.Test.Phoenix.ControllerAssertions do
  @moduledoc false
  alias Phoenix.ConnTest
  alias Plug.Conn
  alias Pow.Phoenix.{Controller, Routes, Messages}

  @spec assert_authenticated_redirect(Plug.Conn.t()) :: no_return
  defmacro assert_authenticated_redirect(conn) do
    quote do
      assert ConnTest.redirected_to(unquote(conn)) == Routes.after_sign_in_path(unquote(conn))
      assert ConnTest.get_flash(unquote(conn), :error) == Messages.user_already_authenticated(unquote(conn))
    end
  end

  @spec assert_not_authenticated_redirect(Plug.Conn.t()) :: no_return
  defmacro assert_not_authenticated_redirect(conn) do
    quote do
      assert ConnTest.redirected_to(unquote(conn)) == Controller.router_helpers(unquote(conn)).pow_session_path(unquote(conn), :new, request_url: Conn.request_url(unquote(conn)))
      assert ConnTest.get_flash(unquote(conn), :error) == Messages.user_not_authenticated(unquote(conn))
    end
  end
end

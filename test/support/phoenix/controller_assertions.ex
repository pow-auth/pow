defmodule Pow.Test.Phoenix.ControllerAssertions do
  @moduledoc false
  alias Phoenix.ConnTest

  @spec assert_authenticated_redirect(Plug.Conn.t()) :: no_return
  defmacro assert_authenticated_redirect(conn) do
    quote do
      assert ConnTest.redirected_to(unquote(conn)) == "/"
      assert ConnTest.get_flash(unquote(conn), :error) == "You're already authenticated."
    end
  end

  @spec assert_not_authenticated_redirect(Plug.Conn.t()) :: no_return
  defmacro assert_not_authenticated_redirect(conn) do
    quote do
      assert ConnTest.redirected_to(unquote(conn)) == "/"
      assert ConnTest.get_flash(unquote(conn), :error) == "You're not authenticated."
    end
  end
end

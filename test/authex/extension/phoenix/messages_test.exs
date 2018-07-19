defmodule Authex.Extension.Phoenix.MessagesTest do
  alias Phoenix.ConnTest

  defmodule Phoenix.Messages do
    use Authex.Extension.Phoenix.Messages.Base

    def message(:a, _conn), do: "First"
    def message(:b, _conn), do: "Second"
  end

  defmodule Messages do
    use Authex.Extension.Phoenix.Messages,
      extensions: [Authex.Extension.Phoenix.MessagesTest]

    def authex(:a, _conn), do: "Overridden"
  end

  use ExUnit.Case
  doctest Authex.Extension.Phoenix.Messages

  test "can override messages" do
    conn =
      :get
      |> ConnTest.build_conn("/")
      |> Authex.Plug.put_config([])

    assert Messages.authex(:a, nil) == "Overridden"
    assert Messages.authex(:b, conn) == "Second"

    assert Phoenix.Messages.msg(:a, conn) == "First"
    assert Phoenix.Messages.msg(:b, conn) == "Second"

    conn = Authex.Plug.put_config(conn, [messages_backend: Messages])

    assert Phoenix.Messages.msg(:a, conn) == "Overridden"
    assert Phoenix.Messages.msg(:b, conn) == "Second"
  end
end

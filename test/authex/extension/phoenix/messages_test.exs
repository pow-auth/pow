defmodule Authex.Extension.Phoenix.MessagesTest do
  defmodule Phoenix.Messages do
    def a(_conn), do: "First"
    def b(_conn), do: "Second"
  end

  defmodule Messages do
    use Authex.Extension.Phoenix.Messages,
      extensions: [Authex.Extension.Phoenix.MessagesTest]

    def authex_a(_conn), do: "Overridden"
  end

  use ExUnit.Case
  doctest Authex.Extension.Phoenix.Messages

  test "can override messages" do
    assert Messages.authex_a(nil) == "Overridden"
    assert Messages.authex_b(nil) == "Second"
  end
end

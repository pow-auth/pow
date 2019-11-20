defmodule Pow.Extension.Phoenix.MessagesTest do
  # Implementation needed for `Pow.Extension.Base.has?/2` check
  defmodule ExtensionMock do
    use Pow.Extension.Base

    @impl true
    def phoenix_messages?(), do: true
  end

  defmodule ExtensionMock.Phoenix.Messages do
    def a(_conn), do: "First"
    def b(_conn), do: "Second"
  end

  defmodule Messages do
    use Pow.Extension.Phoenix.Messages,
      extensions: [Pow.Extension.Phoenix.MessagesTest.ExtensionMock]

    def pow_extension_phoenix_messages_test_extension_mock_a(_conn), do: "Overridden"
  end

  use ExUnit.Case
  doctest Pow.Extension.Phoenix.Messages

  test "can override messages" do
    assert Messages.pow_extension_phoenix_messages_test_extension_mock_a(nil) == "Overridden"
    assert Messages.pow_extension_phoenix_messages_test_extension_mock_b(nil) == "Second"
  end

  test "has fallback module" do
    assert Messages.Pow.Extension.Phoenix.MessagesTest.ExtensionMock.Phoenix.Messages.a(nil) == "Overridden"
  end
end

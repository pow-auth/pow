defmodule Authex.Extension.Phoenix.ControllerTest do
  defmodule Phoenix.Messages do
    def a(_conn), do: "First"
    def b(_conn), do: "Second"
  end

  defmodule Messages do
    use Authex.Extension.Phoenix.Messages,
      extensions: [Authex.Extension.Phoenix.ControllerTest]

    def authex_a(_conn), do: "Overridden"
  end

  use ExUnit.Case
  doctest Authex.Extension.Phoenix.Controller

  alias Authex.Extension.Phoenix.Controller

  test "can fetch message from custom module" do
    conn = %{private: %{authex_config: []}}
    assert Controller.message(Phoenix.Messages, :a, conn) == "First"
    assert Controller.message(Phoenix.Messages, :b, conn) == "Second"

    conn = %{private: %{authex_config: [messages_backend: Messages]}}
    assert Controller.message(Phoenix.Messages, :a, conn) == "Overridden"
    assert Controller.message(Phoenix.Messages, :b, conn) == "Second"
  end
end

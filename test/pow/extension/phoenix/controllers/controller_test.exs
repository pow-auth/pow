defmodule Pow.Extension.Phoenix.ControllerTest do
  defmodule Phoenix.Messages do
    def a(_conn), do: "First"
    def b(_conn), do: "Second"
  end

  defmodule Messages do
    use Pow.Extension.Phoenix.Messages,
      extensions: [Pow.Extension.Phoenix.ControllerTest]

    def pow_a(_conn), do: "Overridden"
  end

  use ExUnit.Case
  doctest Pow.Extension.Phoenix.Controller

  alias Pow.Extension.Phoenix.Controller

  test "can fetch message from custom module" do
    conn = %{private: %{pow_config: []}}
    assert Controller.message(Phoenix.Messages, :a, conn) == "First"
    assert Controller.message(Phoenix.Messages, :b, conn) == "Second"

    conn = %{private: %{pow_config: [messages_backend: Messages]}}
    assert Controller.message(Phoenix.Messages, :a, conn) == "Overridden"
    assert Controller.message(Phoenix.Messages, :b, conn) == "Second"
  end
end

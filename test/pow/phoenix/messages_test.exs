defmodule Pow.Phoenix.MessagesTest do
  defmodule CustomMessages do
    use Pow.Phoenix.Messages

    def signed_out(nil), do: "Custom"
  end

  use ExUnit.Case
  doctest Pow.Phoenix.Messages
  alias Pow.Phoenix.Messages

  test "can customize messages" do
    assert Messages.signed_out(nil) == "You've been signed out. See you soon!"
    assert Messages.signed_in(nil) == "Welcome! You've been signed in."

    assert CustomMessages.signed_out(nil) == "Custom"
    assert CustomMessages.signed_in(nil) == "Welcome! You've been signed in."
  end
end

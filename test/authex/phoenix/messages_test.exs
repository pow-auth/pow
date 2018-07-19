defmodule Authex.Phoenix.MessagesTest do
  defmodule CustomMessages do
    use Authex.Phoenix.Messages

    def signed_out(nil), do: "Custom"
  end

  use ExUnit.Case
  doctest Authex.Phoenix.Messages
  alias Authex.Phoenix.Messages

  test "can customize messages" do
    assert Messages.signed_out(nil) == "Signed out successfullly."
    assert Messages.signed_in(nil) == "User successfully signed in."

    assert CustomMessages.signed_out(nil) == "Custom"
    assert CustomMessages.signed_in(nil) == "User successfully signed in."
  end
end

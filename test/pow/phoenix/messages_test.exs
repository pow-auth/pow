defmodule Pow.Phoenix.MessagesTest do
  defmodule CustomMessages do
    use Pow.Phoenix.Messages

    def signed_out(nil), do: "Custom"
  end

  use ExUnit.Case
  doctest Pow.Phoenix.Messages
  alias Pow.Phoenix.Messages

  test "can customize messages" do
    conn = nil

    assert is_nil(Messages.signed_out(conn))
    assert Messages.invalid_credentials(conn) == "The provided login details did not work. Please verify your credentials, and try again."

    assert CustomMessages.signed_out(conn) == "Custom"
    assert CustomMessages.invalid_credentials(conn) == "The provided login details did not work. Please verify your credentials, and try again."
  end
end

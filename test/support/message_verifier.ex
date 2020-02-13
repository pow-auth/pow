defmodule Pow.Test.MessageVerifier do
  @moduledoc false

  @behaviour Pow.Plug.MessageVerifier

  @impl true
  def sign(_conn, salt, message, _config),
    do: "signed.#{salt}.#{message}"

  @impl true
  def verify(_conn, salt, message, _config) do
    prepend = "signed." <> salt <> "."

    case String.replace(message, prepend, "") do
      ^message -> :error
      message  -> {:ok, message}
    end
  end
end

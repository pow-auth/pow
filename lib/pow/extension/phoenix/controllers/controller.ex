defmodule Pow.Extension.Phoenix.Controller do
  @moduledoc """
  Used with Pow Extension Phoenix controllers to handle messages and routes.
  """
  alias Pow.Phoenix.{Controller, Messages}
  alias Pow.Extension.Phoenix.Messages, as: ExtensionMessages

  @spec message(atom(), atom(), Conn.t()) :: atom()
  def message(extension, method, conn) do
    case Controller.messages(conn) do
      Messages ->
        mod = extension

        apply(mod, method, [conn])

      mod ->
        method = ExtensionMessages.method_name(extension, method)

        apply(mod, method, [conn])
    end
  end
end

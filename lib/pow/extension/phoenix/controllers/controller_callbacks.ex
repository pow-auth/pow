defmodule Pow.Extension.Phoenix.ControllerCallbacks do
  @moduledoc """
  Module that adds controller callbacks for extensions.

  It'll automatically trigger all extension callbacks.

  ## Usage

      use Pow.Plug.Session,
        controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
        extensions: [PowExtensionA, PowExtensionB]
  """
  alias Pow.{Config, Extension}

  for hook <- [:before_process, :before_respond] do
    @doc false
    @spec unquote(hook)(atom(), atom(), any(), Config.t()) :: any()
    def unquote(hook)(controller, action, results, config) do
      config
      |> controller_callbacks_modules()
      |> Enum.reduce(results, fn
        _extension, {:halt, conn} -> {:halt, conn}
        extension, results        -> extension.unquote(hook)(controller, action, results, config)
      end)
    end
  end

  defp controller_callbacks_modules(config) do
    config
    |> Extension.Config.extensions()
    |> Extension.Config.extension_modules(["Phoenix", "ControllerCallbacks"])
  end
end

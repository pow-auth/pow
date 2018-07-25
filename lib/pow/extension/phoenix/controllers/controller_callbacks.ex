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
    @spec unquote(hook)(atom(), atom(), any(), Config.t()) :: any()
    def unquote(hook)(controller, action, results, config) do
      config
      |> modules()
      |> Enum.reduce(results, fn extension, results ->
        extension.unquote(hook)(controller, action, results, config)
      end)
    end
  end

  defp modules(config) do
    Extension.Config.discover_modules(config, ["Phoenix", "ControllerCallbacks"])
  end
end

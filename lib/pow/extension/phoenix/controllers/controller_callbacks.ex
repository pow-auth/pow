defmodule Pow.Extension.Phoenix.ControllerCallbacks do
  @moduledoc """
  Module that handles controller callbacks for extensions.
  """
  alias Pow.{Config, Extension}

  @spec callback(atom(), atom(), any(), Config.t()) :: any()
  def callback(controller, action, res, config) do
    reduce(config, res, fn extension, res ->
      extension.callback(controller, action, res, config)
    end)
  end

  defp reduce(config, acc, method) do
    config
    |> Extension.Config.extensions()
    |> Enum.map(&Module.concat([&1, "Phoenix", "ControllerCallbacks"]))
    |> Enum.reduce(acc, method)
  end
end

defmodule Pow.Extension.Config do
  @moduledoc """
  Configuration helpers for extensions.
  """
  alias Pow.Config

  @spec extensions(Config.t()) :: [atom()]
  def extensions(config) do
    Config.get(config, :extensions, [])
  end
end

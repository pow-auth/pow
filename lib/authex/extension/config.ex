defmodule Authex.Extension.Config do
  @moduledoc """
  Configuration helpers for extensions.
  """
  alias Authex.Config

  @spec extensions(Config.t()) :: [atom()]
  def extensions(config) do
    Config.get(config, :extensions, [])
  end
end

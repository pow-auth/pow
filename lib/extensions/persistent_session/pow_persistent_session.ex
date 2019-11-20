defmodule PowPersistentSession do
  @moduledoc false
  use Pow.Extension.Base

  @impl true
  def phoenix_controller_callbacks?(), do: true
end

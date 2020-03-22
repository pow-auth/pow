defmodule PowInvitation do
  @moduledoc false
  use Pow.Extension.Base

  @impl true
  def ecto_schema?(), do: true

  @impl true
  def use_ecto_schema?(), do: true

  @impl true
  def phoenix_router?(), do: true

  @impl true
  def phoenix_messages?(), do: true

  @impl true
  def phoenix_templates() do
    [
      {"invitation", ~w(new show edit)}
    ]
  end
end

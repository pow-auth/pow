defmodule Authex do
  @moduledoc """
  A module that provides authentication system for your Phoenix app.
  """
  @spec config() :: Keyword.t()
  def config(), do: Application.get_env(:authex, Authex, [])
end

defmodule Authex.Authentication do
  @moduledoc """
  A module that handles struct authentication.
  """
  @spec authenticate(module(), map()) :: {:ok, map()} | {:error, term()}
  def authenticate(mod, params) do
    mod.authenticate(params)
  end
end

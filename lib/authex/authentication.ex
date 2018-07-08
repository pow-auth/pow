defmodule Authex.Authentication do
  @moduledoc """
  A module that handles struct authentication.
  """
  alias Authex.Config

  @spec authenticate(Keyword.t(), map()) :: {:ok, map()} | {:error, term()} | no_return
  def authenticate(config, params) do
    mod = Config.get(config, :user_mod, nil) || Config.raise_error(no_user_mod_error())

    mod.authenticate(params)
  end

  defp no_user_mod_error,
    do: "Can't find user module. Please add the correct user module by setting the :user_mod config value."
end

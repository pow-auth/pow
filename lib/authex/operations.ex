defmodule Authex.Operations do
  @moduledoc """
  A module that handles struct operations (User).
  """
  alias Authex.Config

  @spec authenticate(Config.t(), map()) :: {:ok, map()} | {:error, term()} | no_return
  def authenticate(config, params) do
    module(config).authenticate(params)
  end

  @spec changeset(Config.t(), map()) :: map()
  def changeset(config, user_or_params) do
    module(config).changeset(user_or_params)
  end

  @spec create(Config.t(), map()) :: {:ok, map()} | {:error, map()} | no_return
  def create(config, params) do
    module(config).create(params)
  end

  @spec update(Config.t(), map(), map()) :: {:ok, map()} | {:error, map()} | no_return
  def update(config, user, params) do
    module(config).update(user, params)
  end

  @spec delete(Config.t(), map()) :: {:ok, map()} | {:error, map()} | no_return
  def delete(config, user) do
    module(config).delete(user)
  end

  defp module(config) do
    Config.get(config, :user_mod, nil) || Config.raise_error(no_user_mod_error())
  end

  defp no_user_mod_error,
    do: "Can't find user module. Please add the correct user module by setting the :user_mod config value."
end

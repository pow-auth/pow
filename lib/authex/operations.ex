defmodule Authex.Operations do
  @moduledoc """
  A module that handles struct operations (User).
  """
  alias Authex.{Config, Ecto.UsersContext}

  @spec authenticate(Config.t(), map()) :: map() | nil | no_return
  def authenticate(config, params) do
    module(config).authenticate(config, params)
  end

  @spec changeset(Config.t(), map()) :: map()
  def changeset(config, params) do
    module(config).changeset(config, params)
  end
  @spec changeset(Config.t(), map(), map()) :: map()
  def changeset(config, user, params) do
    module(config).changeset(user, config, params)
  end

  @spec create(Config.t(), map()) :: {:ok, map()} | {:error, map()} | no_return
  def create(config, params) do
    module(config).create(config, params)
  end

  @spec update(Config.t(), map(), map()) :: {:ok, map()} | {:error, map()} | no_return
  def update(config, user, params) do
    module(config).update(config, user, params)
  end

  @spec delete(Config.t(), map()) :: {:ok, map()} | {:error, map()} | no_return
  def delete(config, user) do
    module(config).delete(config, user)
  end

  defp module(config) do
    Config.get(config, :users_context, UsersContext)
  end
end

defmodule Pow.Operations do
  @moduledoc """
  A module that handles struct operations (User).
  """
  alias Pow.{Config, Ecto.Context}

  @spec changeset(Config.t(), map()) :: map() | nil | no_return
  def changeset(config, params) do
    user_mod = Config.user_module(config)
    changeset(config, struct(user_mod), params)
  end

  @spec changeset(Config.t(), map(), map()) :: map()
  def changeset(config, user, params) do
    user_mod = Config.user_module(config)
    user_mod.changeset(user, params)
  end

  @spec authenticate(Config.t(), map()) :: map() | nil | no_return
  def authenticate(config, params) do
    case context_module(config) do
      Context -> Context.authenticate(config, params)
      module  -> module.authenticate(params)
    end
  end

  @spec create(Config.t(), map()) :: {:ok, map()} | {:error, map()} | no_return
  def create(config, params) do
    case context_module(config) do
      Context -> Context.create(config, params)
      module  -> module.create(params)
    end
  end

  @spec update(Config.t(), map(), map()) :: {:ok, map()} | {:error, map()} | no_return
  def update(config, user, params) do
    case context_module(config) do
      Context -> Context.update(config, user, params)
      module  -> module.update(user, params)
    end
  end

  @spec delete(Config.t(), map()) :: {:ok, map()} | {:error, map()} | no_return
  def delete(config, user) do
    case context_module(config) do
      Context -> Context.delete(config, user)
      module  -> module.delete(user)
    end
  end

  @spec get_by(Config.t(), Keyword.t() | map()) :: map() | nil | no_return
  def get_by(config, user) do
    case context_module(config) do
      Context -> Context.get_by(config, user)
      module  -> module.get_by(user)
    end
  end

  defp context_module(config) do
    Config.get(config, :users_context, Context)
  end
end

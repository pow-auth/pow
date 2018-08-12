defmodule Pow.Operations do
  @moduledoc """
  Operation methods that glues operation calls to context module.

  A custom context module can be used instead of the default `Pow.Ecto.Context`
  if a `:users_context` key is passed in the configuration.
  """
  alias Pow.{Config, Ecto.Context}

  @doc """
  Build a changeset from a blank user struct.

  It'll use the schema module fetched from the config through
  `Pow.Ecto.Context.user_schema_mod/1`.
  """
  @spec changeset(Config.t(), map()) :: map() | nil
  def changeset(config, params) do
    user_mod = Context.user_schema_mod(config)
    user     = user_mod.__struct__()

    changeset(config, user, params)
  end

  @doc """
  Build a changeset from existing user struct.

  It'll call the `changeset/2` method on the user struct.
  """
  @spec changeset(Config.t(), map(), map()) :: map()
  def changeset(_config, user, params) do
    user.__struct__.changeset(user, params)
  end

  @doc """
  Authenticate a user.

  This calls `Pow.Ecto.Context.authenticate/2` or `authenticate/1` on a custom
  context module.
  """
  @spec authenticate(Config.t(), map()) :: map() | nil
  def authenticate(config, params) do
    case context_module(config) do
      Context -> Context.authenticate(config, params)
      module  -> module.authenticate(params)
    end
  end

  @doc """
  Create a new user.

  This calls `Pow.Ecto.Context.create/2` or `create/1` on a custom context
  module.
  """
  @spec create(Config.t(), map()) :: {:ok, map()} | {:error, map()}
  def create(config, params) do
    case context_module(config) do
      Context -> Context.create(config, params)
      module  -> module.create(params)
    end
  end

  @doc """
  Update an existing user.

  This calls `Pow.Ecto.Context.update/3` or `update/2` on a custom context
  module.
  """
  @spec update(Config.t(), map(), map()) :: {:ok, map()} | {:error, map()}
  def update(config, user, params) do
    case context_module(config) do
      Context -> Context.update(config, user, params)
      module  -> module.update(user, params)
    end
  end

  @doc """
  Delete an existing user.

  This calls `Pow.Ecto.Context.delete/2` or `delete/1` on a custom context
  module.
  """
  @spec delete(Config.t(), map()) :: {:ok, map()} | {:error, map()}
  def delete(config, user) do
    case context_module(config) do
      Context -> Context.delete(config, user)
      module  -> module.delete(user)
    end
  end

  @doc """
  Retrieve a user with the provided clauses.

  This calls `Pow.Ecto.Context.get_by/2` or `get_by/1` on a custom context
  module.
  """
  @spec get_by(Config.t(), Keyword.t() | map()) :: map() | nil
  def get_by(config, clauses) do
    case context_module(config) do
      Context -> Context.get_by(config, clauses)
      module  -> module.get_by(clauses)
    end
  end

  defp context_module(config) do
    Config.get(config, :users_context, Context)
  end
end

defmodule Pow.Operations do
  @moduledoc """
  Operation functions that glues operation calls to context module.

  A custom context module can be used instead of the default `Pow.Ecto.Context`
  if a `:users_context` key is passed in the configuration.
  """
  alias Pow.{Config, Ecto.Context}

  @doc """
  Build a changeset from a blank user struct.

  It'll use the schema module fetched from the config through
  `Pow.Config.user!/1`.
  """
  @spec changeset(map(), Config.t()) :: map() | nil
  def changeset(params, config) do
    user_mod = Config.user!(config)
    user     = user_mod.__struct__()

    changeset(user, params, config)
  end

  @doc """
  Build a changeset from existing user struct.

  It'll call the `changeset/2` function on the user struct.
  """
  @spec changeset(map(), map(), Config.t()) :: map()
  def changeset(user, params, _config) do
    user.__struct__.changeset(user, params)
  end

  @doc """
  Authenticate a user.

  This calls `Pow.Ecto.Context.authenticate/2` or `authenticate/1` on a custom
  context module.
  """
  @spec authenticate(map(), Config.t()) :: map() | nil
  def authenticate(params, config) do
    case context_module(config) do
      Context -> Context.authenticate(params, config)
      module  -> module.authenticate(params)
    end
  end

  @doc """
  Create a new user.

  This calls `Pow.Ecto.Context.create/2` or `create/1` on a custom context
  module.
  """
  @spec create(map(), Config.t()) :: {:ok, map()} | {:error, map()}
  def create(params, config) do
    case context_module(config) do
      Context -> Context.create(params, config)
      module  -> module.create(params)
    end
  end

  @doc """
  Update an existing user.

  This calls `Pow.Ecto.Context.update/3` or `update/2` on a custom context
  module.
  """
  @spec update(map(), map(), Config.t()) :: {:ok, map()} | {:error, map()}
  def update(user, params, config) do
    case context_module(config) do
      Context -> Context.update(user, params, config)
      module  -> module.update(user, params)
    end
  end

  @doc """
  Delete an existing user.

  This calls `Pow.Ecto.Context.delete/2` or `delete/1` on a custom context
  module.
  """
  @spec delete(map(), Config.t()) :: {:ok, map()} | {:error, map()}
  def delete(user, config) do
    case context_module(config) do
      Context -> Context.delete(user, config)
      module  -> module.delete(user)
    end
  end

  @doc """
  Retrieve a user with the provided clauses.

  This calls `Pow.Ecto.Context.get_by/2` or `get_by/1` on a custom context
  module.
  """
  @spec get_by(Keyword.t() | map(), Config.t()) :: map() | nil
  def get_by(clauses, config) do
    case context_module(config) do
      Context -> Context.get_by(clauses, config)
      module  -> module.get_by(clauses)
    end
  end

  defp context_module(config) do
    Config.get(config, :users_context, Context)
  end

  @doc """
  Retrieve a keyword list of primary key value(s) from the provided struct.

  The keys will be fetched from the `__schema__/1` function in the struct
  module. If no `__schema__/1` function exists, then it's expected that the
  struct has `:id` as its only primary key.
  """
  @spec fetch_primary_key_values(struct(), Config.t()) :: {:ok, keyword()} | {:error, term()}
  def fetch_primary_key_values(%mod{} = struct, _config) do
    cond do
      not Code.ensure_loaded?(mod) ->
        {:error, "The module #{inspect mod} does not exist"}

      function_exported?(mod, :__schema__, 1) ->
        :primary_key
        |> mod.__schema__()
        |> map_primary_key_values(struct, [])

      true ->
        map_primary_key_values([:id], struct, [])
    end
  end

  defp map_primary_key_values([], %mod{}, []), do: {:error, "No primary keys found for #{inspect mod}"}
  defp map_primary_key_values([key | rest], %mod{} = struct, acc) do
    case Map.get(struct, key) do
      nil   -> {:error, "Primary key value for key `#{inspect key}` in #{inspect mod} can't be `nil`"}
      value -> map_primary_key_values(rest, struct, acc ++ [{key, value}])
    end
  end
  defp map_primary_key_values([], _struct, acc), do: {:ok, acc}

  @doc """
  Takes a struct and will reload it.

  The clauses are fetched with `fetch_primary_key_values/2`, and the struct
  loaded with `get_by/2`. A `RuntimeError` exception will be raised if the clauses
  could not be fetched.
  """
  @spec reload(struct(), Config.t()) :: struct() | nil
  def reload(struct, config) do
    case fetch_primary_key_values(struct, config) do
      {:error, error} -> raise error
      {:ok, clauses}  -> get_by(clauses, config)
    end
  end
end

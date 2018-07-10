defmodule Authex.Ecto.UsersContext.Behaviour do
  @moduledoc false

  @type user :: map()

  alias Ecto.Changeset
  alias Authex.Config

  @callback changeset(user() | Changeset.t(), Config.t(), map()) :: Changeset.t()
  @callback authenticate(Config.t(), map()) :: user() | nil
  @callback create(Config.t(), map()) :: {:ok, user()} | {:error, Changeset.t()}
  @callback update(Config.t(), user(), map()) :: {:ok, user()} | {:error, Changeset.t()}
  @callback delete(Config.t(), user()) :: {:ok, user()} | {:error, Changeset.t()}
end

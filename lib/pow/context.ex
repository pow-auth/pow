defmodule Pow.Context do
  @moduledoc """
  Used to set up context API.
  """
  @type user() :: map()
  @type changeset() :: map()

  @callback authenticate(map()) :: user() | nil
  @callback create(map()) :: {:ok, user()} | {:error, changeset()}
  @callback update(user(), map()) :: {:ok, user()} | {:error, changeset()}
  @callback delete(user()) :: {:ok, user()} | {:error, changeset()}
  @callback get_by(Keyword.t() | map()) :: user() | nil
end

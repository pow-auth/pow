defmodule Pow.Store.Backend.Base do
  @moduledoc """
  Used to set up API for key-value cache store.

  ## Usage

      defmodule MyApp.RedisCache do
        @behaviour Base

        # ...
      end
  """
  alias Pow.Config

  @type key() :: [binary() | atom()] | binary()
  @type record() :: {key(), any()}
  @type key_match() :: [atom() | binary()]

  @callback put(Config.t(), record() | [record()]) :: :ok
  @callback delete(Config.t(), key()) :: :ok
  @callback get(Config.t(), key()) :: any() | :not_found
  @callback all(Config.t(), key_match()) :: [record()]
end

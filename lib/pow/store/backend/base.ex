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

  @callback put(Config.t(), binary(), any()) :: :ok
  @callback delete(Config.t(), binary()) :: :ok
  @callback get(Config.t(), binary()) :: any() | :not_found
  @callback keys(Config.t()) :: [any()]
end

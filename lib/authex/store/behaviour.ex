defmodule Authex.Store.Behaviour do
  @moduledoc false

  alias Authex.Config

  @callback put(Config.t(), binary(), any()) :: :ok
  @callback delete(Config.t(), binary()) :: :ok
  @callback get(Config.t(), binary()) :: any() | :not_found
end

defmodule Authex.Config do
  @moduledoc """
  A module that handles configurations.
  """
  @type t :: Keyword.t()
  defmodule ConfigError do
    defexception [:message]
  end

  @spec current_user_assigns_key(t()) :: atom()
  def current_user_assigns_key(config) do
    get(config, :current_user_assigns_key, :current_user)
  end

  @spec get(t(), atom(), any()) :: any()
  def get(config, key, default) do
    Keyword.get(config, key, get_global(key, default))
  end

  @spec put(t(), atom(), any()) :: t()
  def put(config, key, value) do
    Keyword.put(config, key, value)
  end

  defp get_global(key, default) do
    Keyword.get(Authex.config(), key, default)
  end

  @spec raise_error(binary()) :: no_return
  def raise_error(message) do
    raise ConfigError, message: message
  end
end

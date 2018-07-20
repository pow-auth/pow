defmodule Pow.Config do
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

  @spec user_module(t()) :: atom()
  def user_module(config) do
    get(config, :user, nil) || raise_no_user_error()
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
    Keyword.get(Pow.config(), key, default)
  end

  @spec raise_no_user_error :: no_return
  defp raise_no_user_error do
    raise_error("No :user configuration option found for user schema module.")
  end

  @spec raise_error(binary()) :: no_return
  def raise_error(message) do
    raise ConfigError, message: message
  end
end

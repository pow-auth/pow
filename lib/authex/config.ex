defmodule Authex.Config do
  defmodule ConfigError do
    defexception [:message]
  end

  @spec current_user_assigns_key(Keyword.t()) :: atom()
  def current_user_assigns_key(config) do
    get(config, :current_user_assigns_key, :current_user)
  end

  @spec get(Keyword.t(), atom(), any()) :: any()
  def get(config, key, default) do
    Keyword.get(config, key, get_global(key, default))
  end

  defp get_global(key, default) do
    Keyword.get(Authex.config(), key, default)
  end

  @spec raise_error(binary()) :: no_return
  def raise_error(message) do
    raise ConfigError, message: message
  end
end

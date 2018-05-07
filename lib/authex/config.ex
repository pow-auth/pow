defmodule Authex.Config do
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
end

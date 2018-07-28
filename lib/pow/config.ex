defmodule Pow.Config do
  @moduledoc """
  Methods to parse and modify configurations.
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
    Keyword.get(config, key, get_env_config(config, key, default))
  end

  @spec put(t(), atom(), any()) :: t()
  def put(config, key, value) do
    Keyword.put(config, key, value)
  end

  @spec merge(t(), t()) :: t()
  def merge(l_config, r_config) do
    Keyword.merge(l_config, r_config)
  end

  defp get_env_config(config, key, default) do
    config
    |> env_config()
    |> Keyword.get(key, default)
  end

  defp env_config(config) do
    case Keyword.get(config, :otp_app, nil) do
      nil     -> Application.get_all_env(:pow)
      otp_app -> Application.get_env(otp_app, :pow, [])
    end
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

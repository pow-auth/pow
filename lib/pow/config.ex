defmodule Pow.Config do
  @moduledoc """
  Methods to parse and modify configurations.
  """
  @type t :: Keyword.t()
  defmodule ConfigError do
    defexception [:message]
  end

  @doc """
  Gets the key value from the configuration.

  If not found, it'll fallback to environment config, and lastly to the default
  value.
  """
  @spec get(t(), atom(), any()) :: any()
  def get(config, key, default) do
    Keyword.get(config, key, get_env_config(config, key, default))
  end

  @doc """
  Puts a new key value to the configuration.
  """
  @spec put(t(), atom(), any()) :: t()
  def put(config, key, value) do
    Keyword.put(config, key, value)
  end

  @doc """
  Merges two configurations.
  """
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

  @doc """
  Raise a ConfigError exception.
  """
  @spec raise_error(binary()) :: no_return
  def raise_error(message) do
    raise ConfigError, message: message
  end
end

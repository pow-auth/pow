defmodule Pow.Config do
  @moduledoc """
  Functions to parse and modify configurations.
  """
  @type t :: Keyword.t()
  defmodule ConfigError do
    @moduledoc false
    defexception [:message]
  end

  @doc """
  Gets the key value from the configuration.

  If not found, it'll fall back to environment config, and lastly to the
  default value which is `nil` if not specified.
  """
  @spec get(t(), atom(), any()) :: any()
  def get(config, key, default \\ nil) do
    case Keyword.get(config, key, :not_found) do
      :not_found -> get_env_config(config, key, default)
      value      -> value
    end
  end

  defp get_env_config(config, key, default, env_key \\ :pow) do
    config
    |> Keyword.get(:otp_app)
    |> case do
      nil     -> Application.get_all_env(env_key)
      otp_app -> Application.get_env(otp_app, env_key, [])
    end
    |> Keyword.get(key, default)
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

  @doc """
  Raise a ConfigError exception.
  """
  @spec raise_error(binary()) :: no_return()
  def raise_error(message) do
    raise ConfigError, message: message
  end

  @doc """
  Retrieves the repo module from the config, or raises an exception.
  """
  @spec repo!(t()) :: atom()
  def repo!(config) do
    get(config, :repo) || raise_error("No `:repo` configuration option found.")
  end

  @doc """
  Retrieves the user schema module from the config, or raises an exception.
  """
  @spec user!(t()) :: atom()
  def user!(config) do
    get(config, :user) || raise_error("No `:user` configuration option found.")
  end
end

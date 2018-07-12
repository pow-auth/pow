defmodule Authex.Store.CredentialsCache do
  @moduledoc """
  API for caching credentials with Authex.Store.EtsCache.
  """
  @behaviour Authex.Store.Behaviour

  alias Authex.{Config, Store.EtsCache}

  @default_ttl     :timer.hours(48)
  @cache_namespace "credentials"

  @spec put(Config.t(), binary(), any()) :: :ok
  def put(config, key, value) do
    config
    |> parse_config()
    |> EtsCache.put(key, value)
  end

  @spec delete(Config.t(), binary()) :: :ok
  def delete(config, key) do
    config
    |> parse_config()
    |> EtsCache.delete(key)
  end

  @spec get(Config.t(), binary()) :: any() | :not_found
  def get(config, key) do
    config
    |> parse_config()
    |> EtsCache.get(key)
  end

  defp parse_config(config) do
    ttl = Config.get(config, :credentials_cache_ttl, @default_ttl)

    config
    |> Config.put(:ets_cache_namespace, @cache_namespace)
    |> Config.put(:ets_cache_ttl, ttl)
  end
end

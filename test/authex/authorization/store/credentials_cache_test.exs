defmodule Authex.Authorization.Plug.CredentialsCacheTest do
  use ExUnit.Case
  doctest Authex

  alias Authex.Authorization.Store.CredentialsCache

  @default_config [
    credentials_cache_namespace: "authex:test:",
    credentials_cache_name: "credentials",
    credentials_cache_ttl: :timer.hours(48)
  ]

  test "initializes" do
    {:ok, _pid} = CredentialsCache.start_link(@default_config)
    refute :ets.info(CredentialsCache) == :undefined
  end

  test "can push and retrieve values" do
    {:ok, _pid} = CredentialsCache.start_link(@default_config)

    assert CredentialsCache.get(@default_config, "key") == :not_found
    CredentialsCache.put(@default_config, "key", "value")
    :timer.sleep(100)
    assert CredentialsCache.get(@default_config, "key") == "value"
  end

  test "values auto purge" do
    {:ok, _pid} = CredentialsCache.start_link(@default_config)

    config = Keyword.put(@default_config, :credentials_cache_ttl, 100)

    CredentialsCache.put(config, "key", "value")
    :timer.sleep(50)
    assert CredentialsCache.get(config, "key") == "value"
    :timer.sleep(100)
    assert CredentialsCache.get(config, "key") == :not_found
  end
end

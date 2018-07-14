defmodule Authex.Store.CredentialsCacheTest do
  use ExUnit.Case
  doctest Authex.Store.CredentialsCache

  alias Authex.{Store.CredentialsCache, Config}

  @default_config [
    credentials_cache_namespace: "authex:test:",
    credentials_cache_name: "credentials",
    credentials_cache_ttl: :timer.hours(48)
  ]

  test "can put, get and delete records" do
    assert CredentialsCache.get(@default_config, "key") == :not_found

    CredentialsCache.put(@default_config, "key", "value")
    :timer.sleep(100)
    assert CredentialsCache.get(@default_config, "key") == "value"

    CredentialsCache.delete(@default_config, "key")
    :timer.sleep(100)
    assert CredentialsCache.get(@default_config, "key") == :not_found
  end

  test "records auto purge" do
    config = Config.put(@default_config, :credentials_cache_ttl, 100)

    CredentialsCache.put(config, "key", "value")
    :timer.sleep(50)
    assert CredentialsCache.get(config, "key") == "value"
    :timer.sleep(100)
    assert CredentialsCache.get(config, "key") == :not_found
  end
end

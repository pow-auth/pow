defmodule Pow.Store.Backend.EtsCacheTest do
  use ExUnit.Case
  doctest Pow.Store.Backend.EtsCache

  alias Pow.{Config, Store.Backend.EtsCache}

  @default_config [namespace: "pow:test", ttl: :timer.hours(1)]

  test "can put, get and delete records" do
    assert EtsCache.get(@default_config, "key") == :not_found

    EtsCache.put(@default_config, "key", "value")
    :timer.sleep(100)
    assert EtsCache.get(@default_config, "key") == "value"

    EtsCache.delete(@default_config, "key")
    :timer.sleep(100)
    assert EtsCache.get(@default_config, "key") == :not_found
  end

  test "records auto purge" do
    config = Config.put(@default_config, :ttl, 100)

    EtsCache.put(config, "key", "value")
    :timer.sleep(50)
    assert EtsCache.get(config, "key") == "value"
    :timer.sleep(100)
    assert EtsCache.get(config, "key") == :not_found
  end
end

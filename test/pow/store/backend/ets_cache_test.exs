defmodule Pow.Store.Backend.EtsCacheTest do
  use ExUnit.Case
  doctest Pow.Store.Backend.EtsCache

  alias Pow.{Config, Store.Backend.EtsCache}

  @default_config [namespace: "pow:test", ttl: :timer.hours(1)]

  setup do
    start_supervised!({EtsCache, []})

    :ok
  end

  test "can put, get and delete records" do
    assert EtsCache.get(@default_config, "key") == :not_found

    EtsCache.put(@default_config, {"key", "value"})
    :timer.sleep(100)
    assert EtsCache.get(@default_config, "key") == "value"

    EtsCache.delete(@default_config, "key")
    :timer.sleep(100)
    assert EtsCache.get(@default_config, "key") == :not_found
  end

  test "can put multiple records at once" do
    EtsCache.put(@default_config, [{"key1", "1"}, {"key2", "2"}])
    :timer.sleep(100)
    assert EtsCache.get(@default_config, "key1") == "1"
    assert EtsCache.get(@default_config, "key2") == "2"
  end

  test "with no `:ttl` option" do
    config = [namespace: "pow:test"]

    EtsCache.put(config, {"key", "value"})
    :timer.sleep(100)
    assert EtsCache.get(config, "key") == "value"

    EtsCache.delete(config, "key")
    :timer.sleep(100)
  end

  test "can match fetch all" do
    EtsCache.put(@default_config, {"key1", "value"})
    EtsCache.put(@default_config, {"key2", "value"})
    EtsCache.put(@default_config, {["namespace", "key"], "value"})
    :timer.sleep(100)

    assert EtsCache.all(@default_config, :_) ==  [{"key1", "value"}, {"key2", "value"}]
    assert EtsCache.all(@default_config, ["namespace", :_]) ==  [{["namespace", "key"], "value"}]
  end

  test "records auto purge" do
    config = Config.put(@default_config, :ttl, 100)

    EtsCache.put(config, {"key", "value"})
    EtsCache.put(config, [{"key1", "1"}, {"key2", "2"}])
    :timer.sleep(50)
    assert EtsCache.get(config, "key") == "value"
    assert EtsCache.get(config, "key1") == "1"
    assert EtsCache.get(config, "key2") == "2"
    :timer.sleep(100)
    assert EtsCache.get(config, "key") == :not_found
    assert EtsCache.get(config, "key1") == :not_found
    assert EtsCache.get(config, "key2") == :not_found
  end
end

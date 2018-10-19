defmodule Pow.Store.Backend.MnesiaCacheTest do
  use ExUnit.Case
  doctest Pow.Store.Backend.MnesiaCache

  alias Pow.{Config, Store.Backend.MnesiaCache}

  @default_config [namespace: "pow:test", ttl: :timer.hours(1)]

  setup do
    :mnesia.kill()

    File.rm_rf!("tmp/mnesia")
    File.mkdir_p!("tmp/mnesia")

    {:ok, pid} = MnesiaCache.start_link([])

    {:ok, pid: pid}
  end

  test "can put, get and delete records with persistent storage", %{pid: pid} do
    assert MnesiaCache.get(@default_config, "key") == :not_found

    MnesiaCache.put(@default_config, "key", "value")
    :timer.sleep(100)
    assert MnesiaCache.get(@default_config, "key") == "value"

    restart(pid, @default_config)

    assert MnesiaCache.get(@default_config, "key") == "value"

    MnesiaCache.delete(@default_config, "key")
    :timer.sleep(100)
    assert MnesiaCache.get(@default_config, "key") == :not_found
  end

  test "fetch keys" do
    MnesiaCache.put(@default_config, "key1", "value")
    MnesiaCache.put(@default_config, "key2", "value")
    :timer.sleep(100)

    assert MnesiaCache.keys(@default_config) == ["pow:test:key1", "pow:test:key2"]
  end

  test "records auto purge with persistent storage", %{pid: pid} do
    config = Config.put(@default_config, :ttl, 100)

    MnesiaCache.put(config, "key", "value")
    :timer.sleep(50)
    assert MnesiaCache.get(config, "key") == "value"
    :timer.sleep(100)
    assert MnesiaCache.get(config, "key") == :not_found

    MnesiaCache.put(config, "key", "value")
    restart(pid, config)
    assert MnesiaCache.get(config, "key") == "value"
    :timer.sleep(100)
    assert MnesiaCache.get(config, "key") == :not_found
  end

  defp restart(pid, config) do
    GenServer.stop(pid)
    :mnesia.stop()
    MnesiaCache.start_link(config)
  end
end

defmodule Pow.Store.BaseTest do
  use ExUnit.Case
  doctest Pow.Store.Base

  alias Pow.Store.Base

  defmodule BackendCacheMock do
    def get(_config, :backend), do: :mock_backend
    def get(config, :config), do: config
  end

  defmodule BaseMock do
    use Base,
      namespace: "default_namespace",
      ttl: :timer.seconds(10)
  end

  test "fetches from custom backend" do
    config = [backend: BackendCacheMock]

    assert BaseMock.get(config, :backend) == :mock_backend
    assert BaseMock.get(config, :config) == [ttl: :timer.seconds(10), namespace: "default_namespace"]
  end

  test "preset config can be overridden" do
    default_config  = []
    override_config = [ttl: 100, namespace: "overridden_namespace"]

    assert BaseMock.get(default_config, :test) == :not_found
    assert BaseMock.get(override_config, :test) == :not_found

    BaseMock.put(default_config, :test, :value)
    BaseMock.put(override_config, :test, :value)
    :timer.sleep(50)

    assert BaseMock.get(default_config, :test) == :value
    assert BaseMock.get(override_config, :test) == :value
    :timer.sleep(50)

    assert BaseMock.get(default_config, :test) == :value
    assert BaseMock.get(override_config, :test) == :not_found
  end
end

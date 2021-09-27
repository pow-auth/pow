defmodule Pow.Store.BaseTest do
  use ExUnit.Case
  doctest Pow.Store.Base

  alias Pow.Store.{Backend.EtsCache, Base}

  defmodule BackendCacheMock do
    def get(_config, :backend), do: :mock_backend
    def get(config, :config), do: config

    def all(_config, _key_match), do: []
  end

  defmodule BaseMock do
    use Base,
      namespace: "default_namespace",
      ttl: :timer.seconds(10)
  end

  setup do
    start_supervised!({EtsCache, []})

    :ok
  end

  test "fetches from custom backend" do
    config = [backend: BackendCacheMock]

    assert BaseMock.get(config, :backend) == :mock_backend
    assert BaseMock.get(config, :config) == [ttl: :timer.seconds(10), namespace: "default_namespace"]
  end

  test "preset config can be overridden" do
    default_config  = []
    override_config = [ttl: 50, namespace: "overridden_namespace"]

    assert BaseMock.get(default_config, :test) == :not_found
    assert BaseMock.get(override_config, :test) == :not_found

    BaseMock.put(default_config, :test, :value)
    BaseMock.put(override_config, :test, :value)
    assert BaseMock.get(default_config, :test) == :value
    assert BaseMock.get(override_config, :test) == :value
    :timer.sleep(100)

    assert BaseMock.get(default_config, :test) == :value
    assert BaseMock.get(override_config, :test) == :not_found
  end

  defmodule BackwardsCompabilityMock do
    def put(config, key, value) do
      send(self(), {:put, key(config, key), value})
    end

    def get(config, key) do
      send(self(), {:get, key(config, key)})

      :value
    end

    def delete(config, key) do
      send(self(), {:delete, key(config, key)})

      :ok
    end

    def keys(_config) do
      [:erlang.term_to_binary([BackwardsCompabilityMock, :id, 2])]
    end

    defp key(config, key) do
      "#{Pow.Config.get(config, :namespace, "cache")}:#{key}"
    end
  end

  alias ExUnit.CaptureIO

  # TODO: Remove by 1.1.0
  test "backwards compatible with binary keys support" do
    config = [backend: BackwardsCompabilityMock]

    key = [BackwardsCompabilityMock, :id, 2]
    binary_key = "default_namespace:#{:erlang.term_to_binary(key)}"
    binary_key_warning = "binary key for backend stores is depecated, update `Pow.Store.BaseTest.BackwardsCompabilityMock` to accept erlang terms instead"

    assert CaptureIO.capture_io(:stderr, fn ->
      assert BaseMock.put(config, key, :value) == :ok
      assert_received {:put, ^binary_key, :value}
    end) =~ binary_key_warning

    assert CaptureIO.capture_io(:stderr, fn ->
      assert BaseMock.get(config, key) == :value
      assert_received {:get, ^binary_key}
    end) =~ binary_key_warning

    assert CaptureIO.capture_io(:stderr, fn ->
      assert BaseMock.delete(config, key) == :ok
      assert_received {:delete, ^binary_key}
    end)

    assert CaptureIO.capture_io(:stderr, fn ->
      assert BaseMock.all(config, [BackwardsCompabilityMock | :_]) == [{key, :value}]
      assert BaseMock.all(config, [BackwardsCompabilityMock, :id, :_]) == [{key, :value}]
      assert BaseMock.all(config, [BackwardsCompabilityMock, :id, 3]) == []
    end)
  end
end

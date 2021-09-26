defmodule Pow.Store.Backend.EtsCacheTest do
  use ExUnit.Case
  doctest Pow.Store.Backend.EtsCache

  alias Pow.{Config, Store.Backend.EtsCache}

  @default_config [namespace: "pow:test"]

  setup do
    start_supervised!({EtsCache, []})

    :ok
  end

  test "can put, get and delete records" do
    assert EtsCache.get(@default_config, "key") == :not_found

    EtsCache.put(@default_config, {"key", "value"})
    assert EtsCache.get(@default_config, "key") == "value"

    EtsCache.delete(@default_config, "key")
    assert EtsCache.get(@default_config, "key") == :not_found
  end

  test "with `writes: :async` config option" do
    config = Keyword.put(@default_config, :writes, :async)

    EtsCache.put(config, {"key", "value"})
    assert EtsCache.get(config, "key") == :not_found
    :timer.sleep(100)
    assert EtsCache.get(config, "key") == "value"

    EtsCache.delete(config, "key")
    assert EtsCache.get(config, "key") == "value"
    :timer.sleep(100)
    assert EtsCache.get(config, "key") == :not_found
  end

  test "can put multiple records at once" do
    EtsCache.put(@default_config, [{"key1", "1"}, {"key2", "2"}])
    assert EtsCache.get(@default_config, "key1") == "1"
    assert EtsCache.get(@default_config, "key2") == "2"
  end

  test "can match fetch all" do
    EtsCache.put(@default_config, {"key1", "value"})
    EtsCache.put(@default_config, {"key2", "value"})
    EtsCache.put(@default_config, {["namespace", "key"], "value"})

    assert EtsCache.all(@default_config, :_) ==  [{"key1", "value"}, {"key2", "value"}]
    assert EtsCache.all(@default_config, ["namespace", :_]) ==  [{["namespace", "key"], "value"}]
  end

  test "with `:ttl` option records auto purge" do
    config = Config.put(@default_config, :ttl, 50)

    EtsCache.put(config, {"key", "value"})
    EtsCache.put(config, [{"key1", "1"}, {"key2", "2"}])
    assert EtsCache.get(config, "key") == "value"
    assert EtsCache.get(config, "key1") == "1"
    assert EtsCache.get(config, "key2") == "2"
    :timer.sleep(100)
    assert EtsCache.get(config, "key") == :not_found
    assert EtsCache.get(config, "key1") == :not_found
    assert EtsCache.get(config, "key2") == :not_found
  end

  # TODO: Remove by 1.1.0
  test "backwards compatible" do
    assert_capture_io_eval(quote do
      assert EtsCache.put(unquote(@default_config), "key", "value") == :ok
    end, "Pow.Store.Backend.EtsCache.put/3 is deprecated. Use `put/2` instead")

    assert_capture_io_eval(quote do
      assert EtsCache.keys(unquote(@default_config)) == [{"key", "value"}]
    end, "Pow.Store.Backend.EtsCache.keys/1 is deprecated. Use `all/2` instead")
  end

  alias ExUnit.CaptureIO

  defp assert_capture_io_eval(quoted, message) do
    System.version()
    |> Version.match?(">= 1.8.0")
    |> case do
      true ->
        # Due to https://github.com/elixir-lang/elixir/pull/9626 it's necessary to
        # import `ExUnit.Assertions`
        pre_elixir_1_10_quoted =
          quote do
            import ExUnit.Assertions
          end

        assert CaptureIO.capture_io(:stderr, fn ->
          Code.eval_quoted([pre_elixir_1_10_quoted, quoted])
        end) =~ message

      false ->
        IO.warn("Please upgrade to Elixir 1.8 to captured and assert IO message: #{inspect message}")

        :ok
    end
  end
end

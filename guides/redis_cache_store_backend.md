# Redis cache store backend

For read-only systems, like Heroku, you won't be able to use the built-in Mnesia backend cache for distribution and to persist cache data between restarts. Instead, let's use [Redix](https://github.com/whatyouhide/redix) to store our cache data in Redis.

First, add Redix to your list of dependencies in `mix.exs`:

```elixir
# mix.exs
defp deps do
  [
    # ...
    {:redix, "~> 0.9.2"}
  ]
end
```

Now set up your `WEB_PATH/pow/redis_cache.ex` like so:

```elixir
# lib/my_app_web/pow/redis_cache.ex
defmodule MyAppWeb.Pow.RedisCache do
  @moduledoc """
  Redis based key value store with auto expiration.

  ## Configuration options

    * `:ttl` - integer value in milliseconds for ttl of records. If this value
      is not provided, or is set to nil, the records will never expire.

    * `:namespace` - value to use for namespacing keys. Defaults to "cache".

    * `:writes` - set to `:async` to do asynchronous writes. Defauts to
      `:sync`.
  """
  @behaviour Pow.Store.Backend.Base

  alias Pow.Config

  @redix_instance_name :redix

  @impl true
  def put(config, record_or_records) do
    ttl = Config.get(config, :ttl) || raise_ttl_error!()

    commands =
      record_or_records
      |> List.wrap()
      |> Enum.map(fn {key, value} ->
        config
        |> binary_redis_key(key)
        |> put_command(value, ttl)
      end)

    maybe_async(config, fn ->
      @redix_instance_name
      |> Redix.pipeline!(commands)
      |> Enum.map(fn
        "OK"  -> nil
        error -> error
      end)
      |> Enum.reject(&is_nil/1)
      |> case do
        []     -> :ok
        errors -> raise "Redix failed SET because of #{inspect errors}"
      end
    end)

    :ok
  end

  defp put_command(key, value, ttl) do
    value = :erlang.term_to_binary(value)

    ["SET", key, value, "PX", ttl]
  end

  defp maybe_async(config, fun) do
    case Config.get(config, :writes, :sync) do
      :sync -> fun.()
      :async -> Task.start(fun)
    end
  end

  @impl true
  def delete(config, key) do
    key =
      config
      |> redis_key(key)
      |> to_binary_redis_key()

    maybe_async(config, fn ->
      Redix.command!(@redix_instance_name, ["DEL", key])
    end)

    :ok
  end

  @impl true
  def get(config, key) do
    key =
      config
      |> redis_key(key)
      |> to_binary_redis_key()

    case Redix.command!(@redix_instance_name, ["GET", key]) do
      nil   -> :not_found
      value -> :erlang.binary_to_term(value)
    end
  end

  @impl true
  def all(config, key_match) do
    compiled_match_spec = :ets.match_spec_compile([{{key_match, :_}, [], [:"$_"]}])

    Stream.resource(
      fn -> do_scan(config, compiled_match_spec, "0") end,
      &stream_scan(config, compiled_match_spec, &1),
      fn _ -> :ok end)
    |> Enum.to_list()
  end

  defp stream_scan(_config, _compiled_match_spec, {[], "0"}), do: {:halt, nil}
  defp stream_scan(config, compiled_match_spec, {[], iterator}) do
    result = do_scan(config, compiled_match_spec, iterator)

    stream_scan(config, compiled_match_spec, result)
  end
  defp stream_scan(_config, _compiled_match_spec, {keys, iterator}), do: {keys, {[], iterator}}

  defp do_scan(config, compiled_match_spec, iterator) do
    prefix = to_binary_redis_key([namespace(config)]) <> ":*"

    [iterator, res] = Redix.command!(@redix_instance_name, ["SCAN", iterator, "MATCH", prefix])

    {filter_or_load_value(compiled_match_spec, res, config), iterator}
  end

  defp filter_or_load_value(compiled_match_spec, keys, config) do
    keys
    |> Enum.map(&convert_key/1)
    |> Enum.sort()
    |> :ets.match_spec_run(compiled_match_spec)
    |> populate_values(config)
  end

  defp convert_key(key) do
    key =
      key
      |> from_binary_redis_key()
      |> unwrap()

    {key, nil}
  end

  defp unwrap([_namespace, key]), do: key
  defp unwrap([_namespace | key]), do: key

  defp populate_values([], _config), do: []
  defp populate_values(records, config) do
    binary_keys = Enum.map(records, fn {key, nil} -> binary_redis_key(config, key) end)

    values =
      @redix_instance_name
      |> Redix.command!(["MGET"] ++ binary_keys)
      |> Enum.map(&:erlang.binary_to_term/1)

    records
    |> zip_values(values)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp zip_values([{key, nil} | next1], [value | next2]) do
    [{key, value} | zip_values(next1, next2)]
  end
  defp zip_values(_, []), do: []
  defp zip_values([], _), do: []

  defp binary_redis_key(config, key) do
    config
    |> redis_key(key)
    |> to_binary_redis_key()
  end

  defp redis_key(config, key) do
    [namespace(config) | List.wrap(key)]
  end

  defp namespace(config), do: Config.get(config, :namespace, "cache")

  defp to_binary_redis_key(key) do
    key
    |> Enum.map(fn part ->
      part
      |> :erlang.term_to_binary()
      |> Base.url_encode64(padding: false)
    end)
    |> Enum.join(":")
  end

  defp from_binary_redis_key(key) do
    key
    |> String.split(":")
    |> Enum.map(fn part ->
      part
      |> Base.url_decode64!(padding: false)
      |> :erlang.binary_to_term()
    end)
  end

  @spec raise_ttl_error! :: no_return()
  defp raise_ttl_error!,
    do: Config.raise_error("`:ttl` configuration option is required for #{inspect(__MODULE__)}")
end
```

We are converting keys to binary keys since we can't directly use the Erlang terms as with ETS and Mnesia.

We'll need to start the Redix application on our app startup, so in `application.ex` add `{Redix, name: :redix}` to your supervision tree:

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do

  # ...

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      # ...
      {Redix, name: :redix}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ...
end
```

By default localhost Redis is used, but you can update this by using a Redis URI: `{Redix, {"redis://:secret@redix.example.com:6380/1", [name: :redix]}}`

Finally update the config with your new Redis cache backend:

```elixir
# config/config.ex
config :my_app, :pow,
  user: MyApp.Users.User,
  repo: MyApp.Repo,
  cache_store_backend: MyAppWeb.Pow.RedisCache
```

And now you have a running Redis cache store backend!

## Test module

```elixir
# test/my_app_web/pow/redis_cache_test.exs
defmodule MyAppWeb.Pow.RedisCacheTest do
  use ExUnit.Case
  doctest MyAppWeb.Pow.RedisCache

  alias MyAppWeb.Pow.RedisCache

  @default_config [namespace: "test", ttl: :timer.hours(1)]

  setup do
    Redix.command!(:redix, ["FLUSHALL"])

    :ok
  end

  test "can put, get and delete records" do
    assert RedisCache.get(@default_config, "key") == :not_found

    RedisCache.put(@default_config, {"key", "value"})
    assert RedisCache.get(@default_config, "key") == "value"

    RedisCache.delete(@default_config, "key")
    assert RedisCache.get(@default_config, "key") == :not_found
  end

  test "with `writes: :async` config option" do
    config = Keyword.put(@default_config, :writes, :async)

    assert RedisCache.get(config, "key") == :not_found

    RedisCache.put(config, {"key", "value"})
    assert RedisCache.get(config, "key") == :not_found
    :timer.sleep(100)
    assert RedisCache.get(config, "key") == "value"

    RedisCache.delete(config, "key")
    assert RedisCache.get(config, "key") == "value"
    :timer.sleep(100)
    assert RedisCache.get(config, "key") == :not_found
  end

  describe "with redis errors" do
    setup do
      ["maxmemory", value] = Redix.command!(:redix, ["CONFIG", "GET", "maxmemory"])

      Redix.command!(:redix, ["CONFIG", "SET", "maxmemory", "10"])

      on_exit(fn ->
        Redix.command!(:redix, ["CONFIG", "SET", "maxmemory", value])
      end)
    end

    test "raises error" do
      assert_raise(RuntimeError, "Redix failed SET because of [%Redix.Error{message: \"OOM command not allowed when used memory > 'maxmemory'.\"}]", fn ->
        RedisCache.put(@default_config, {"key", "value"})
      end)
    end
  end

  test "can put multiple records at once" do
    RedisCache.put(@default_config, [{"key1", "1"}, {"key2", "2"}])
    assert RedisCache.get(@default_config, "key1") == "1"
    assert RedisCache.get(@default_config, "key2") == "2"
  end

  test "can match fetch all" do
    assert RedisCache.all(@default_config, :_) == []

    for number <- 1..11, do: RedisCache.put(@default_config, {"key#{number}", "value"})
    items = RedisCache.all(@default_config, :_)

    assert Enum.find(items, fn {key, "value"} -> key == "key1" end)
    assert Enum.find(items, fn {key, "value"} -> key == "key2" end)
    assert length(items) == 11

    RedisCache.put(@default_config, {["namespace", "key"], "value"})
    assert RedisCache.all(@default_config, ["namespace", :_]) ==  [{["namespace", "key"], "value"}]
  end

  test "records auto purge" do
    config = Keyword.put(@default_config, :ttl, 50)

    RedisCache.put(config, {"key", "value"})
    RedisCache.put(config, [{"key1", "1"}, {"key2", "2"}])
    assert RedisCache.get(config, "key") == "value"
    assert RedisCache.get(config, "key1") == "1"
    assert RedisCache.get(config, "key2") == "2"
    :timer.sleep(100)
    assert RedisCache.get(config, "key") == :not_found
    assert RedisCache.get(config, "key1") == :not_found
    assert RedisCache.get(config, "key2") == :not_found
  end
end
```

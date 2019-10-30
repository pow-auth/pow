# Redis cache store backend

For read-only systems, like Heroku, you won't be able to use the built-in Mnesia backend cache for distribution and to persist cache data between restarts. Instead let's use [Redix](https://github.com/whatyouhide/redix) to store our cache data in Redis.

First add Redix to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    # ...
    {:redix, "~> 0.9.2"}
  ]
end
```

Now set up your `WEB_PATH/pow_redis_cache.ex` like so:

```elixir
defmodule MyAppWeb.PowRedisCache do
  @behaviour Pow.Store.Backend.Base

  alias Pow.Config

  @redix_instance_name :redix

  @impl true
  def put(config, record_or_records) do
    ttl      = Config.get(config, :ttl) || raise_ttl_error()
    commands =
      record_or_records
      |> List.wrap()
      |> Enum.map(fn {key, value} ->
        config
        |> binary_redis_key(key)
        |> put_command(value, ttl)
      end)

    Redix.noreply_pipeline(@redix_instance_name, commands)
  end

  defp put_command(key, value, ttl) do
    value = :erlang.term_to_binary(value)

    ["SET", key, value, "PX", ttl]
  end

  @impl true
  def delete(config, key) do
    key =
      config
      |> redis_key(key)
      |> to_binary_redis_key()

    Redix.noreply_command(@redix_instance_name, ["DEL", key])
  end

  @impl true
  def get(config, key) do
    key =
      config
      |> redis_key(key)
      |> to_binary_redis_key()

    case Redix.command(@redix_instance_name, ["GET", key]) do
      {:ok, nil}   -> :not_found
      {:ok, value} -> :erlang.binary_to_term(value)
    end
  end

  @impl true
  def all(config, match_spec) do
    compiled_match_spec = :ets.match_spec_compile([{match_spec, [], [:"$_"]}])

    Stream.resource(
      fn -> do_scan(config, compiled_match_spec, "0") end,
      &stream_scan(config, compiled_match_spec, &1),
      fn _ -> :ok end)
    |> Enum.to_list()
    |> case do
      []   -> []
      keys -> fetch_values_for_keys(keys, config)
    end
  end

  defp fetch_values_for_keys(keys, config) do
    binary_keys = Enum.map(keys, &binary_redis_key(config, &1))

    case Redix.command(@redix_instance_name, ["MGET"] ++ binary_keys) do
      {:ok, values} ->
        values = Enum.map(values, &:erlang.binary_to_term/1)

        keys
        |> Enum.zip(values)
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    end
  end

  defp stream_scan(_config, _compiled_match_spec, {[], "0"}), do: {:halt, nil}
  defp stream_scan(config, compiled_match_spec, {[], iterator}), do: do_scan(config, compiled_match_spec, iterator)
  defp stream_scan(_config, _compiled_match_spec, {keys, iterator}), do: {keys, {[], iterator}}

  defp do_scan(config, compiled_match_spec, iterator) do
    prefix = to_binary_redis_key([namespace(config)]) <> ":*"

    case Redix.command(@redix_instance_name, ["SCAN", iterator, "MATCH", prefix]) do
      {:ok, [iterator, res]} -> {filter_or_load_value(compiled_match_spec, res), iterator}
    end
  end

  defp filter_or_load_value(compiled_match_spec, keys) do
    keys
    |> Enum.map(&convert_key/1)
    |> Enum.sort()
    |> :ets.match_spec_run(compiled_match_spec)
  end

  defp convert_key(key) do
    key
    |> from_binary_redis_key()
    |> unwrap()
  end

  defp unwrap([_namespace, key]), do: key
  defp unwrap([_namespace | key]), do: key

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

  @spec raise_ttl_error :: no_return
  defp raise_ttl_error,
    do: Config.raise_error("`:ttl` configuration option is required for #{inspect(__MODULE__)}")
end

```

We are converting keys to binary keys since we can't directly use the Erlang terms as with ETS and Mnesia.

We'll need to start the Redix application on our app startup, so in `application.ex` add `{Redix, name: :redix}` to your supervision tree:

```elixir
  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      # ...
      {Redix, name: :redix}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
```

By default localhost Redis is used, but you can update this by using a Redis URI: `{Redix, {"redis://:secret@redix.example.com:6380/1", [name: :redix]}}`

Finally update the config with your new Redis cache backend:

```elixir
config :my_app, :pow,
  user: MyApp.Users.User,
  repo: MyApp.Repo,
  cache_store_backend: MyAppWeb.PowRedisCache
```

And now you've a running Redis cache store backend!

## Test module

```elixir
defmodule MyAppWeb.PowRedisCacheTest do
  use ExUnit.Case
  doctest MyAppWeb.PowRedisCache

  alias MyAppWeb.PowRedisCache

  @default_config [namespace: "test", ttl: :timer.hours(1)]

  setup do
    start_supervised!({Redix, host: "localhost", port: 6379, name: :redix})
    Redix.command!(:redix, ["FLUSHALL"])

    :ok
  end

  test "can put, get and delete records" do
    assert PowRedisCache.get(@default_config, "key") == :not_found

    PowRedisCache.put(@default_config, {"key", "value"})
    :timer.sleep(100)
    assert PowRedisCache.get(@default_config, "key") == "value"

    PowRedisCache.delete(@default_config, "key")
    :timer.sleep(100)
    assert PowRedisCache.get(@default_config, "key") == :not_found
  end

  test "can put multiple records at once" do
    PowRedisCache.put(@default_config, [{"key1", "1"}, {"key2", "2"}])
    :timer.sleep(100)
    assert PowRedisCache.get(@default_config, "key1") == "1"
    assert PowRedisCache.get(@default_config, "key2") == "2"
  end

  test "can match fetch all" do
    PowRedisCache.put(@default_config, {"key1", "value"})
    PowRedisCache.put(@default_config, {"key2", "value"})
    :timer.sleep(100)

    assert PowRedisCache.all(@default_config, :_) ==  [{"key1", "value"}, {"key2", "value"}]

    PowRedisCache.put(@default_config, {["namespace", "key"], "value"})
    :timer.sleep(100)

    assert PowRedisCache.all(@default_config, ["namespace", :_]) ==  [{["namespace", "key"], "value"}]
  end

  test "records auto purge" do
    config = Keyword.put(@default_config, :ttl, 100)

    PowRedisCache.put(config, {"key", "value"})
    PowRedisCache.put(config, [{"key1", "1"}, {"key2", "2"}])
    :timer.sleep(50)
    assert PowRedisCache.get(config, "key") == "value"
    assert PowRedisCache.get(config, "key1") == "1"
    assert PowRedisCache.get(config, "key2") == "2"
    :timer.sleep(100)
    assert PowRedisCache.get(config, "key") == :not_found
    assert PowRedisCache.get(config, "key1") == :not_found
    assert PowRedisCache.get(config, "key2") == :not_found
  end
end
```

# Redis cache store backend

For read-only systems, like Heroku, you won't be able to use the built-in Mnesia backend cache for distribution and to persist cache data between restarts. Instead let's use [Redix](https://github.com/whatyouhide/redix) to store our cache data in Redis.

First add Redix to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # ...
    {:redix, "~> 0.9.2"}
  ]
end
```

Now set up your `WEB_PATH/pow_redis_cache.ex` like so:

```elixir
defmodule MyAppWeb.PowRedisCache do
  @behaviour Pow.Store.Base

  alias Pow.Config

  @redix_instance_name :redix

  def put(config, key, value) do
    key     = redis_key(config, key)
    ttl     = Config.get(config, :ttl)
    value   = :erlang.term_to_binary(value)
    command = put_command(key, value, ttl)

    Redix.noreply_command(@redix_instance_name, command)
  end

  def put_command(key, value, ttl) when is_integer(ttl) and ttl > 0, do: ["SET", key, value, "PX", ttl]
  def put_command(key, value, _ttl), do: ["SET", key, value]

  def delete(config, key) do
    key = redis_key(config, key)

    Redix.noreply_command(@redix_instance_name, ["DEL", key])
  end

  def get(config, key) do
    key = redis_key(config, key)

    case Redix.command(@redix_instance_name, ["GET", key]) do
      {:ok, nil}   -> :not_found
      {:ok, value} -> :erlang.binary_to_term(value)
    end
  end

  def keys(config) do
    namespace = redis_key(config, "")
    length    = String.length(namespace)

    {:ok, values} = Redix.command(@redix_instance_name, ["KEYS", "#{namespace}*"])

    Enum.map(values, &String.slice(&1, length..-1))
  end

  defp redis_key(config, key) do
    namespace = Config.get(config, :namespace, "cache")

    "#{namespace}:#{key}"
  end
end
```

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

## Test

Here's a test module for your new Redis cache:

```elixir
defmodule MyAppWeb.PowRedisCacheTest do
  use ExUnit.Case
  doctest MyAppWeb.PowRedisCache

  alias MyAppWeb.PowRedisCache

  @default_config [namespace: "test", ttl: :timer.hours(1)]

  test "can put, get and delete records" do
    assert PowRedisCache.get(@default_config, "key") == :not_found

    PowRedisCache.put(@default_config, "key", "value")
    :timer.sleep(100)
    assert PowRedisCache.get(@default_config, "key") == "value"

    PowRedisCache.delete(@default_config, "key")
    :timer.sleep(100)
    assert PowRedisCache.get(@default_config, "key") == :not_found
  end

  test "fetch keys" do
    PowRedisCache.put(@default_config, "key1", "value")
    PowRedisCache.put(@default_config, "key2", "value")
    :timer.sleep(100)

    assert Enum.sort(PowRedisCache.keys(@default_config)) == ["key1", "key2"]
  end

  test "records auto purge" do
    config = Keyword.put(@default_config, :ttl, 100)

    PowRedisCache.put(config, "key", "value")
    :timer.sleep(50)
    assert PowRedisCache.get(config, "key") == "value"
    :timer.sleep(100)
    assert PowRedisCache.get(config, "key") == :not_found
  end
end
```
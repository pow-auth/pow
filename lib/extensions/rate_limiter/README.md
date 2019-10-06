# PowRateLimiter

This extension will rate limit failed authentications as per [the NIST recommendation](https://pages.nist.gov/800-63-3/sp800-63b.html#throttle). By default this means that a maximum of 100 consecutive failed attempts are permitted. The limit will expire one hour after the last failed attempt.

## Installation

Follow the instructions for extensions in [README.md](../../../README.md#add-extensions-support), and set `PowRateLimiter` in the `:extensions` list.

Remember to start the ETS engine in your application:

```elixir
defmodule MyAppWeb.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      MyAppWeb.Endpoint,
      PowRateLimiter.RateLimiter.Ets
    ]

    opts = [strategy: :one_for_one, name: MyAppWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ...
end
```

The above engine won't work in multi-node cluster, since each node will run its own rate limiter. To resolve that you should either ensure that only one node has the rate limiter, or that the rate limiter replicates the data across the cluster.

## Configuration

This module is build to be as simple as possible, but easy to extend. The following examples will show how you can increase your rate limiting mechanism in a simple way.

### Require CAPTCHA to be solved

TBA

### Progressively incrementing delays

You can increment the timeout progressively with a custom rate limiter leveraging the ETS rate limiter:

TBA

### Use another rate limiter

Here's an example using [Hammer](https://github.com/ExHammer/hammer) for rate limiting:

```elixir
defmodule MyAppWeb.RateLimiter do
  @behavior PowRateLimiter.Engine

  @scale_ms :timer.hours(1)
  @limit 100

  @impl
  def increase_rate_check(fingerprint, _conn, _config) do
    Hammer.check_rate_inc("user:#{fingerprint}", @scale_ms, @limit, 1)
  end

  @impl
  def clear_rate(fingerprint, _conn, _config) do
    Hammer.delete_buckets("user:#{fingerprint}")

    :ok
  end
end
```

Set `pow_rate_limiter_module: MyAppWeb.RateLimiter` in your configuration.

### Lock accounts after rate has been reached

You can [lock accounts](../../../guides/lock_users.md) after a rate has been reached with a custom rate limiter leveraging the ETS rate limiter:

```elixir
defmodule MyAppWeb.RateLimiter do
  @behavior PowRateLimiter.Engine

  alias MyApp.Users
  alias Pow.{Config, Plug}

  @rate_limiter PowRateLimiter.Engine.Ets

  @impl
  def increase_rate_check(fingerprint, conn, config) do
    with {:deny, resp} <- Ets.increase_rate_check(fingerprint, conn, config),
         :ok           <- lock_account(conn) do
      {:deny, resp}
    end
  end

  @impl
  defdelegate clear_rate(fingerprint, conn, config), to: @rate_limiter

  defp lock_account(%{params: %{"user" => %{"email" => email}}}) do
    config = Plug.fetch_config(conn)
    user   = Pow.Ecto.Context.get_by([email: email], config)

    if user, do: MyApp.Users.lock(user)

    :ok
  end
end
```

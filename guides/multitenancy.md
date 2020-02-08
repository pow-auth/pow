# Multitenancy with Pow

You are able to pass repo options to the methods used in `Pow.Ecto.Context` by using the `:repo_opts` configuration option. This makes it possible to pass on the prefix option used in multitenancy apps, so you can do the following:

```elixir
config :my_app, :pow,
  # ...
  repo_opts: [prefix: "tenant_a"]
```

You can also pass the prefix option to `Pow.Plug.Session` in your `endpoint.ex`:

```elixir
plug Pow.Plug.Session, otp_app: :my_app, repo_opts: [prefix: "tenant_a"]
```

And you can add it as a custom plug to use a dynamic prefix value:

```elixir
defmodule MyAppWeb.PowTenantPlug do
  def init(config), do: config

  def call(conn, config) do
    tenant = conn.private[:tenant_prefix]
    config = Keyword.put(config, :repo_opts, [prefix: prefix])

    Pow.Plug.Session.call(conn, config)
  end
end
```

## Triplex

With the above it will make it very easy to set up multitenancy with [Triplex](https://github.com/ateliware/triplex).

First update your `endpoint.ex` using a custom plug rather than the default `Pow.Plug.Session`:

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # ...

  plug Plug.Session, @session_options
  plug MyAppWeb.PowTriplexSessionPlug, otp_app: :my_app
  # ...
end
```

Then set up `pow_triplex_session_plug.ex`:

```elixir
defmodule MyAppWeb.PowTriplexSessionPlug do
  def init(config), do: config

  def call(conn, config) do
    tenant = conn.assigns[:current_tenant] || conn.assigns[:raw_current_tenant]
    prefix = Triplex.to_prefix(tenant)
    config = Keyword.put(config, :repo_opts, [prefix: prefix])

    Pow.Plug.Session.call(conn, config)
  end
end
```

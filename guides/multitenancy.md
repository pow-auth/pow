# Multitenancy with Pow

You can pass repo options to the methods used in `Pow.Ecto.Context` by using the `:repo_opts` configuration option. This makes it possible to pass on the prefix option used in multitenancy apps, so you can do the following:

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
defmodule MyAppWeb.Pow.TenantPlug do
  def init(config), do: config

  def call(conn, config) do
    tenant = conn.private[:tenant_prefix]
    config = Keyword.put(config, :repo_opts, [prefix: prefix])

    Pow.Plug.Session.call(conn, config)
  end
end
```

## Triplex

With the above, it will make it very easy to set up multitenancy with [Triplex](https://github.com/ateliware/triplex).

First, update your `endpoint.ex` using a custom plug rather than the default `Pow.Plug.Session`:

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # ...

  # You should load the tenant with Triplex before calling the
  # `TriplexSessionPlug`. If you use the `ParamPlug` you could add it here:
  # plug Triplex.ParamPlug, param: :subdomain

  # ...

  plug Plug.Session, @session_options
  plug MyAppWeb.Pow.TriplexSessionPlug, otp_app: :my_app
  # ...
end
```

Then set up `WEB_PATH/pow/triplex_session_plug.ex`:

```elixir
defmodule MyAppWeb.Pow.TriplexSessionPlug do
  def init(config), do: config

  def call(conn, config) do
    tenant = conn.assigns[:current_tenant] || conn.assigns[:raw_current_tenant]
    prefix = Triplex.to_prefix(tenant)
    config = Keyword.put(config, :repo_opts, [prefix: prefix])

    Pow.Plug.Session.call(conn, config)
  end
end
```

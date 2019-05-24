# Multi-tenant app

You can pass options to the `Ecto.Repo` methods, by passing the following config option:
```elixir
repo_opts: [prefix: "tenant_a"]
```

So you can use this in e.g. the plug:
```elixir
## endpoint.ex
plug Pow.Plug.Session, otp_app: :my_app, repo_opts: [prefix: "tenant_a"]
```

## With Triplex

This makes it very easy to set up multi-tenant support. As shown with this [Triplex](https://github.com/ateliware/triplex) setup:
```elixir
## endpoint.ex

plug Pow.Plug.Session, otp_app: :my_app

plug Triplex.SubdomainPlug, endpoint: MyAppWeb.Endpoint

plug MyAppWeb.PowTenantPlug, otp_app: :my_app

## pow_tenant_plug.ex
defmodule MyAppWeb.PowTenantPlug do
  def init(config), do: config

  def call(conn, config) do
    tenant = conn.assigns[:current_tenant] || conn.assigns[:raw_current_tenant]
    prefix = Triplex.to_prefix(tenant)
    config = Keyword.put(config, :repo_opts, [prefix: prefix])

    Pow.Plug.Session.call(conn, config)
  end
end
```
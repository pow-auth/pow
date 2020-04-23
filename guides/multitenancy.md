# Multitenancy with Pow

You can pass repo options to the methods used in `Pow.Ecto.Context` by using the `:repo_opts` configuration option. This makes it possible to pass on the prefix option used in multitenancy apps, so you can do the following:

```elixir
config :my_app, :pow,
  # ...
  repo_opts: [prefix: "tenant_a"]
```

You can also pass the prefix option to `Pow.Plug.Session` in your `WEB_PATH/endpoint.ex`:

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

Update your `WEB_PATH/endpoint.ex` using a custom plug rather than the default `Pow.Plug.Session`:

```elixir
# lib/my_app_web/endpoint.ex
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
# lib/my_app_web/pow/triplex_session_plug.ex
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

## Test module

```elixir
# lib/my_app_web/pow/triplex_session_plug_test.exs
defmodule MyAppWeb.Pow.TriplexSessionPlugTest do
  use MyAppWeb.ConnCase

  alias MyAppWeb.Pow.TriplexSessionPlug

  @pow_config [otp_app: :my_app]
  @tenant_a "tenant_a"
  @tenant_b "tenant_b"
  @valid_user_params %{
    "email" => "test@example.com",
    "password" => "password",
    "password_confirmation" => "password"
  }

  setup do
    {:ok, conn: init_conn()}
  end

  test "handles Triplex tenants", %{conn: conn} do
    opts = TriplexSessionPlug.init(@pow_config)
    {:ok, _user, _conn} =
      conn
      |> set_triplex_tenant(@tenant_a)
      |> TriplexSessionPlug.call(opts)
      |> Pow.Plug.create_user(@valid_user_params)

    {:error, _conn} =
      conn
      |> set_triplex_tenant(@tenant_b)
      |> TriplexSessionPlug.call(opts)
      |> Pow.Plug.authenticate_user(@valid_user_params)

    {:ok, _conn} =
      conn
      |> set_triplex_tenant(@tenant_a)
      |> TriplexSessionPlug.call(opts)
      |> Pow.Plug.authenticate_user(@valid_user_params)
  end

  defp init_conn() do
    :get
    |> Plug.Test.conn("/")
    |> Plug.Test.init_test_session(%{})
    |> Phoenix.Controller.fetch_flash()
  end

  defp set_triplex_tenant(conn, tenant) do
    conn = %{conn | params: %{"subdomain" => tenant}}
    opts = Triplex.ParamPlug.init(param: :subdomain)

    Triplex.ParamPlug.call(conn, opts)
  end
end
```

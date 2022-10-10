# Multitenancy with Pow

You can pass repo options to the functions used in `Pow.Ecto.Context` by using the `:repo_opts` configuration option. This makes it possible to pass on the prefix option used in multitenancy apps, so you can do the following:

```elixir
config :my_app, :pow,
  # ...
  repo_opts: [prefix: "tenant_a"]
```

You can also pass the prefix option to `Pow.Plug.Session` in your `WEB_PATH/endpoint.ex`:

```elixir
plug Pow.Plug.Session, otp_app: :my_app, repo_opts: [prefix: "tenant_a"]
```

And you can add it as a custom plug to use a dynamic prefix value (in this case the `conn.private[:tenant_prefix]` has been set beforehand):

```elixir
defmodule MyAppWeb.Pow.TenantPlug do
  def init(config), do: config

  def call(conn, config) do
    prefix = conn.private[:tenant_prefix]
    config = Keyword.put(config, :repo_opts, [prefix: prefix])

    Pow.Plug.Session.call(conn, config)
  end
end
```

## Process dictionary

Another common approach is [to use the process dictionary](https://hexdocs.pm/ecto/3.5.8/multi-tenancy-with-foreign-keys.html). In that case you won't have to pass any repo opts. You just use your modified `MyApp.Repo` module to set and fetch the tenant id in a controller or plug. It could look like:

```elixir
defmodule MyAppWeb.SetTenantPlug do
  def init(opts), do: opts

  def call(conn, _opts_) do
    MyApp.Repo.put_org_id(conn.private[:tenant_org_id])

    conn
  end
end
```

## Triplex

[Triplex](https://github.com/ateliware/triplex) is a database multitenancy package. Pow can be easily configured to work with Triplex.

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

## Triplex create tenant migration with user

You may want to create an new tenant with a Pow user as part of account registration.

First we'll add the account context module that will create an account with a user using an `Ecto.Multi` transaction:

```elixir
# test/my_app/accounts.exs
defmodule MyApp.Accounts do
  alias Ecto.Changeset
  alias MyApp.{Repo, Users.User}

  @otp_app :my_app
  @tenant_param :tenant

  def create_account(tenant_id, params) do
    tenant_id
    |> Triplex.create_schema(Repo, fn (tenant, repo) ->
      do_create_account(tenant, repo, params)
    end)
    |> case do
      {:ok, tenant} -> {:ok, Repo.one!(User, prefix: tenant)}
      {:error, %Changeset{} = changeset} -> {:error, changeset}
      {:error, reason} -> invalid_tenant_changeset_error(params, "couldn't be created", reason)
    end
  end

  defp do_create_account(tenant, repo, params) do
    pow_config =
      [
        otp_app: @otp_app,
        repo: repo,
        user: User,
        repo_opts: [prefix: tenant]
      ]

    Ecto.Multi.new()
    |> Ecto.Multi.run(:triplex_migration, fn repo, %{} ->
      Triplex.migrate(tenant, repo)
    end)
    |> Ecto.Multi.run(:user, fn _, _ ->
      Pow.Ecto.Context.create(params, pow_config)
    end)
    |> repo.transaction()
    |> case do
      {:ok, any} ->
        {:ok, any}

      {:error, :triplex_migration, reason, _} ->
        invalid_tenant_changeset_error(params, "couldn't be created", [reason: reason])

      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  defp invalid_tenant_changeset_error(params, error, keys) do
    changeset =
      %User{}
      |> User.changeset(params)
      |> Changeset.add_error(@tenant_param, error, keys)

    {:error, changeset}
  end
end
```

Next we'll add the controller:

```elixir
# lib/my_app_web/controllers/account_controller.ex
defmodule MyAppWeb.AccountController do
  use MyAppWeb, :controller

  alias MyApp.Accounts

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"account" => tenant_id, "user" => user_params}) do
    case Accounts.create_account(tenant_id, user_params) do
      {:ok, user} ->
        conn
        |> Pow.Plug.create(user)
        |> put_flash(:info, "Welcome!")
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
```

Now all you need is to set up the view and template, and update your router module.

## Triplex test modules

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
    |> fetch_flash()
  end

  defp set_triplex_tenant(conn, tenant) do
    conn = %{conn | params: %{"subdomain" => tenant}}
    opts = Triplex.ParamPlug.init(param: :subdomain)

    Triplex.ParamPlug.call(conn, opts)
  end
end
```

```elixir
# test/my_app/accounts_test.exs
defmodule MyApp.AccountsTest do
  use MyApp.DataCase

  alias MyApp.{Repo, Accounts}

  @tenant_id "test_tenant"
  @tenant_param :tenant
  @valid_params %{email: "test@example.com", password: "secret1234", password_confirmation: "secret1234"}

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)

    Triplex.drop(@tenant_id, Repo)

    on_exit fn ->
      Triplex.drop(@tenant_id, Repo)
    end

    :ok
  end

  test "create_account/2" do
    assert {:ok, user} = Accounts.create_account(@tenant_id, @valid_params)
    assert user.__meta__.prefix == @tenant_id

    assert {:error, changeset} = Accounts.create_account(@tenant_id, @valid_params)
    assert changeset.errors[@tenant_param] == {"couldn't be created", "ERROR 42P06 (duplicate_schema) schema \"#{@tenant_id}\" already exists"}
  end
end
```

```elixir
# test/my_app_web/controllers/account_controller_test.exs
defmodule MyAppWeb.AccountControllerTest do
  use MyAppWeb.ConnCase

  alias MyApp.Repo

  @tenant_id "test-tenant"

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)

    Triplex.drop(@tenant_id, Repo)

    on_exit fn ->
      Triplex.drop(@tenant_id, Repo)
    end

    :ok
  end

  describe "create/2" do
    @valid_params %{"account" => @tenant_id, "user" => %{"email" => "test@example.com", "password" => "secret1234", "password_confirmation" => "secret1234"}}
    @invalid_params %{"account" => @tenant_id, "user" => %{"email" => "test@example.com", "password" => "secret1234"}}

    test "with invalid params", %{conn: conn} do
      conn = post(conn, Routes.account_path(conn, :create, @invalid_params))

      assert html_response(conn, 500)
      refute Pow.Plug.current_user(conn)
    end

    test "with valid params", %{conn: conn} do
      conn = post(conn, Routes.account_path(conn, :create, @valid_params))

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Welcome!"
      assert redirected_to(conn) == Routes.page_path(conn, :index)

      assert Pow.Plug.current_user(conn)
    end
  end
end
```

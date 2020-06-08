# Dealing with multiple user schemas

Pow can handle multiple user schemas out-of-the-box in umbrella projects, or can be configured to handle it in the same Phoenix endpoint.

In this guide we’ll go through the following three options:

 1. [Use roles to diffentiate the users](#1-user-roles)
 2. [Use umbrella project to keep user structs in different endpoint](#2-umbrella-project)
 3. [User structs in same endpoint](#3-same-endpoint)

It’s important that you evaulate your project requirements. Each option gets progressively more complex.

In the following examples we’ll imagine that we work with two types of users: User and Admin.

## 1. User roles

This is the simplest solution as you won’t have to deal with multiple Pow contexts and namespacing. You should head over to the [user roles guide](./user_roles.md) in the Pow docs if a roles setup fit your project requirements.

## 2. Umbrella project

The umbrella project is an easy solution if you have different user structs. Usually the admin and user dashboard are separated, so it’s a natural step to also have them set up as individual Phoenix apps. It may even make development and maintainance easier.

Pow will namespace cookies and sessions with the `:otp_app` name, so all you have to do is to set both Phoenix apps up with Pow.

No additional configuration is required:

```elixir
# apps/my_app_web/config/config.exs
config :my_app_web, :pow,
  repo: MyApp.Repo,
  user: MyApp.Users.User

# apps/my_app_web/lib/my_app_web/endpoint.ex
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app_web

  # ...

  plug Pow.Plug.Session, otp_app: :my_app_web

  plug MyAppWeb.Router
end
```

```elixir
# apps/my_app_admin/config/config.exs
config :my_app_admin, :pow,
  repo: MyApp.Repo,
  user: MyApp.Users.Admin

# apps/my_app_admin/lib/my_app_admin/endpoint.ex
defmodule MyAppAdmin.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app_admin

  # ...

  plug Pow.Plug.Session, otp_app: :my_app_admin

  plug MyAppAdmin.Router
end
```

## 3. Same endpoint

We’ll have to ensure that everything is namespaced right when we deal with multiple Pow configurations in the same endpoint.

It’s assumed that you already have set up your Phoenix app with one Pow configuration, and we’ll add the second user type (the admin in this example).

First configure the endpoint so we ensure that the admin user can be loaded:

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # ...

  plug Pow.Plug.Session,
    repo: MyApp.Repo,
    user: MyApp.Users.Admin,
    current_user_assigns_key: :current_admin,
    session_key: "admin_auth"
  
  plug Pow.Plug.Session, otp_app: :my_app

  plug MyAppWeb.Router
end
```

Now we’ll add Pow routes for the admin user:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router

  # ... pipelines

  pipeline :pow_admin do
    plug :set_pow_config,
      repo: MyApp.Repo,
      user: MyApp.Users.Admin,
      current_user_assigns_key: :current_admin,
      session_key: "admin_auth",
      routes_backend: MyAppWeb.Pow.AdminRoutes,
      plug: Pow.Plug.Session
  end

  defp set_pow_config(conn, config), do: Pow.Plug.put_config(conn, config)

  scope "/" do
    pipe_through :browser

    pow_routes()
  end

  scope "/admin", as: :admin do
    pipe_through [:browser, :pow_admin]
    pow_routes()
  end

  # ... routes
end
```

We’ll have to ensure all paths generated within that pipeline are admin paths with our custom `:routes_backend` module. This module will prepend the controller module name with `Admin` so that `admin_pow_*` route helpers are called instead of the `pow_*` routes:

```elixir
defmodule MyAppWeb.Pow.AdminRoutes do
  use Pow.Phoenix.Routes

  @impl true
  def path_for(conn, plug, verb, vars \\ [], query_params \\ []) do
    plug = Module.concat(["AdminPow", plug])
    Pow.Phoenix.Routes.path_for(conn, plug, verb, vars, query_params)
  end
  
  @impl true
  def url_for(conn, plug, verb, vars \\ [], query_params \\ []) do
    plug = Module.concat(["AdminPow", plug])
    Pow.Phoenix.Routes.url_for(conn, plug, verb, vars, query_params)
  end
end
```

An umbrella project is still preferred since it’s much easier when dealing with multiple Pow contexts.
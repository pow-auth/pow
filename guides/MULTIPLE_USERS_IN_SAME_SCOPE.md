# Set up Pow to handle multiple user structs in same scope

Let's say that you would like to access both a user and admin session in the same scope.

With Pow, you can namespace the configuration in a few steps. Note that the same can be done with less configuration in an umbrella setup using the `:otp_app` configuration.

## Create admin and user schema

```bash
mix pow.ecto.install -r MyApp.Repo Admin admins
mix pow.ecto.install -r MyApp.Repo User users
```

## Set up plugs

Update `WEB_PATH/endpoint.ex` with the two namespaced configurations:

```elixir
plug Pow.Plug.Session,
  repo: MyApp.Repo,
  user: MyApp.User,
  namespace: :user,
  current_user_assigns_key: :current_user

plug Pow.Plug.Session,
  repo: MyApp.Repo,
  user: MyApp.Admin,
  namespace: :admin,
  current_user_assigns_key: :current_admin
```

The user can be accessed in `assigns[:current_user]` and admin in `assigns[:current_admin]`.

## Set up routes

Update `WEB_PATH/router.ex` to access the namespaced configurations:

```elixir
scope "/user", private: %{pow_namespace: :user} do
  pipe_through :browser

  pow_routes()
end

scope "/admin", private: %{pow_namespace: :admin} do
  pipe_through :browser

  pow_routes()
end
```

That's it! Your namespaced configuration is now working with the Pow controllers.

## Modify templates

If you wish to modify the templates, you'll need to generate them with the `namespace` argument:

```bash
mix pow.phoenix.gen.templates --namespace user
```

Then set up the configuration with `web_module: MyAppWeb`. The namespace will automatically be used from the configuration to discover the templates and views. The views will be generated as `MyAppWeb.Pow.NAMESPACE.VIEW`, and templates will be generated in `my_app_web/templates/pow/NAMESPACE`.

This will work for extension and mailer templates too.
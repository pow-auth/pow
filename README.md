# Authex

Authex is a highly flexible and extendable authentication solution for Phoenix and Plug based apps.

## Features

* User registration
* User authentication
* Session based authorization
* Per Endpoint/Plug configuration
* Extendable
* I18n

## Installation

Add Authex to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # ...
    {:authex, "~> 0.1"}
    # ...
  ]
end
```

Run `mix deps.get` to install it.

## Getting started

Install the necessary files:

```bash
mix authex.phoenix.install
```

This will add the following files to your phoenix app:

```bash
LIB_PATH/users/user.ex
PRIV_PATH/repo/migrations/TIMESTAMP_create_user.ex
```

Set up `endpoint.ex` to enable session based authentication:

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # ...

  plug Plug.Session,
    store: :cookie,
    key: "_my_project_demo_key",
    signing_salt: "secret"

  plug Authex.Plug.Session,
    user: MyApp.Users.User

  # ...
end
```

And add the Authex routes and plugs to `router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  user Authex.Phoenix.Router

  # ...

  pipeline :protected do
    plug Authex.Plug.RequireAuthenticated
  end

  scope "/" do
    pipe_through :browser

    authex_routes()
  end

  # ...

  scope "/", MyAppWeb do
    pipe_through [:browser, :protected]

    # Protected routes ...
  end
end
```

That's it! Run `mix ecto.setup`, and you can now visit `http://localhost:4000/registrations/new`, and create a new user.

By default, Authex will only expose files that are absolutely necessary, but you can expose other files such as views and templates using the `mix authex.phoenix.install` command.

## Configuration

Authex is build to be modular, and easy customizable. All configuration in method calls, and plug options will take priority over any environment configuration. This is ideal in case you've an umbrella app with multiple separate user domains.

Authex has four groups of modules that each can used individually, or in conjunction with each other:

### Authex.Plug

This group will handle plug connection. The configuration will be assigned to `conn.private[:authex_config]` and passed through the controller to the users context module. The authorization is session based.

### Authex.Ecto

This group contains all modules related to the Ecto based user schema and context. By default, Authex will use the `Authex.Ecto.UsersContext` module for authenticating, creating, updating and deleting users. However, it's very simple to extend, or write your own user context. Remember to set the `:user_context` configuration key.

### Authex.Phoenix

This contains the controllers, views and templates for Phoenix. Templates are installed in your phoenix library as you would need full control over these files from the start. However, views and controller modules will not be exposed, but you can decide to expose these.

### Change authentication

Authex ships with a session plug module that's enabled by default, but you can easily switch it out with [Guardian](https://github.com/ueberauth/guardian) (or any other plug authentication):

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Authex.Router

  pipeline :protected do
    plug Guardian.Plug.VerifyHeader, key: :impersonate
    plug Guardian.Plug.EnsureAuthenticated, key: :impersonate
  end
end
```

## Plugs

### Authex.Plug.Session

Enables session based authorization. The user struct will be collected from an ETS table through a GenServer using a unique token generated for the session. The token will be reset every time the authorization level changes.

### Authex.Plug.RequireAuthenticated

By default, this will redirect the user to the log in page if the user hasn't been authenticated.

### Authex.Plug.RequireNotAuthenticated

By default, this will redirect the user to the front page if the user is already authenticated.


## Extensions

Authex is made so it's easy to extend the functionality with your own complimentary library. An example is [`authex_roles`]() that makes it possible to add roles to users.

In general extensions follow these requirements:

* Add
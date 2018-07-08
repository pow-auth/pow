# Authex

Authex is a highly flexible and extendable authentication solution for Phoenix and Plug based apps.

## Features

* Per Endpoint/Plug customization
* User registration
* Email confirmation
* Extendable
* Session authentication
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

To install necessary templates, migrations and ecto user schema:

```bash
mix authex.install
```

Set up routes to enable session based authentication:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Authex.Router

  pipeline :browser do
    # ...
    use Authex.Authorization.Plug.Session.Plug.Session,
      user_mod: MyApp.User
  end

  pipeline :protected do
    use Authex.Authroization.Plug.EnsureAuthenticated
  end

  scope "/", MyAppWeb do
    pipe_through :browser
    authex_routes()
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :protected]

    # Routes that requires a user has authenticated.
  end
end
```

That's it! Run `mix ecto.setup`, and you can now visit `http://localhost:4000/registrations/new`, and create a new user.

Authex is highly customizable, and created with multiple configurations in mind (a common use case would be umbrella apps). The plug configuration options takes priority over any environment configuration.

## Migrating from Coherence

If you've previously used Coherence, the migration is simple. You'll have to remove all coherence files such as templates, views, and mailers, and remove all file modifications such as `config.exs`, `user.ex`, etc. After this, you can just follow the steps in **Getting started**, and then customize your configuration. Authex use your existing `User` module.

## Plugs

### Authex.Authentication.Plug.Session

Enables session based authorization. The user struct will be collected from an ETS table through a GenServer using a unique token generated for the session. The token will be updated every time the authorization level changes, or every hour for security.

### Authex.Authentication.Plug.RequireAuthenticated

Used for pages that requires user has authentication.

### Authex.Authentication.Plug.RequireNotAuthenticated

Used for pages that can't be visited for users who have been authenticated.

## Installation

Add Authex to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # ...
    {:authex, git: "https://github.com/danschultzer/authex.git}
    # ...
  ]
end
```

Run `mix deps.get` to install it.

## Set up Authex

Authex will only expose what's necessary for you to configure, but is fully customizable.

To get started, install Authex:

```bash
mix authex.install
```

This will add the following files to your phoenix app:

```bash
LIB_PATH/authex/user.ex
WEB_PATH/templates/authex/registrations/edit.html.eex
WEB_PATH/templates/authex/registrations/new.html.eex
PRIV_PATH/repo/migrations/TIMESTAMP_create_users.ex
```

### Configure authentication

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

## Extensions

Authex is made so it's easy to extend the functionality with your own complimentary library. An example is [`authex_roles`]() that makes it possible to add roles to users.

In general extensions follow these requirements:

* Add
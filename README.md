# Authex

Authex is a flexible authentication solution for Phoenix and Plug based apps.

## Features

* User registration
* Email confirmation
* Extendable
* Session user authentication
* I18n
* Nested configuration level (ideal for apps with separate user tables)

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
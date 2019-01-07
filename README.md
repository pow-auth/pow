# Pow

[![Build Status](https://travis-ci.org/danschultzer/pow.svg?branch=master)](https://travis-ci.org/danschultzer/pow) [![hex.pm](http://img.shields.io/hexpm/v/pow.svg?style=flat)](https://hex.pm/packages/pow)

Pow is a robust, modular, and extendable authentication and user management solution for Phoenix and Plug-based apps.

## Features

* User registration
* Session based authorization
* Per Endpoint/Plug configuration
* Extendable
* I18n
* [And more](guides/WHY_POW.md)

## Installation

Add Pow to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # ...
    {:pow, "~> 1.0.0"}
    # ...
  ]
end
```

Run `mix deps.get` to install it.

## Getting started (Phoenix)

**Umbrella project:** In an umbrella project run `mix pow.ecto.install` inside your Ecto app instead of `mix pow.install`, and then continue with updating `config.ex`, `endpoint.ex` and `router.ex` inside your Phoenix app.

Install the necessary files:

```bash
mix pow.install
```

This will add the following files to your app:

```bash
LIB_PATH/users/user.ex
PRIV_PATH/repo/migrations/TIMESTAMP_create_user.ex
```

Add the following to `config/config.ex`:

```elixir
config :my_app, :pow,
  user: MyApp.Users.User,
  repo: MyApp.Repo
```

Set up `WEB_PATH/endpoint.ex` to enable session based authentication (`Pow.Plug.Session` is added after `Plug.Session`):

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # ...

  plug Plug.Session,
    store: :cookie,
    key: "_my_app_key",
    signing_salt: "secret"

  plug Pow.Plug.Session, otp_app: :my_app

  # ...
end
```

Add Pow routes to `WEB_PATH/router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router

  # ... pipelines

  pipeline :protected do
    plug Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
  end

  scope "/" do
    pipe_through :browser

    pow_routes()
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :protected]

    # Add your protected routes here
  end

  # ... routes
end
```

That's it! Run `mix ecto.setup` and you can now visit `http://localhost:4000/registration/new`, and create a new user.

### Modify templates

By default, Pow will only expose files that are necessary.

If you wish to modify the templates, you can generate them (and the view files) using:

```bash
mix pow.phoenix.gen.templates
```

Remember to add `web_module: MyAppWeb` to the configuration so that the view you've just generated will be used instead:

```elixir
config :my_app, :pow,
  # ...
  web_module: MyAppWeb
```

## Extensions

Pow is made so it's easy to extend the functionality with your own complimentary library. The following extensions are included in this library:

* [PowResetPassword](lib/extensions/reset_password/README.md)
* [PowEmailConfirmation](lib/extensions/email_confirmation/README.md)
* [PowPersistentSession](lib/extensions/persistent_session/README.md)

### Add extensions support

To keep it easy to understand and configure Pow, you'll have to enable the extensions yourself.

Let's install the `PowResetPassword` and `PowEmailConfirmation` extensions.

First, install extension migrations by running:

```bash
mix pow.extension.ecto.gen.migrations --extension PowResetPassword --extension PowEmailConfirmation
```

Then run the migrations with `mix ecto.migrate`. Now, update `config/config.ex` with the `:extensions` and `:controller_callbacks` key:

```elixir
config :my_app, :pow,
  user: MyApp.Users.User,
  repo: MyApp.Repo,
  extensions: [PowResetPassword, PowEmailConfirmation],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks
```

Update `LIB_PATH/users/user.ex` with the extensions:

```elixir
defmodule MyApp.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  use Pow.Extension.Ecto.Schema,
    extensions: [PowResetPassword, PowEmailConfirmation]

  # ...

  def changeset(user_or_changeset, attrs) do
    user_or_changeset
    |> pow_changeset(attrs)
    |> pow_extension_changeset(attrs)
  end
end
```

Add Pow extension routes to `WEB_PATH/router.ex` (note the `:otp_app` configuration that will pull the extensions defined in the app environment):

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router
  use Pow.Extension.Phoenix.Router, otp_app: :my_app

  # ...

  scope "/" do
    pipe_through :browser

    pow_routes()
    pow_extension_routes()
  end

  # ...
end
```

#### Modify extension templates

Templates and views for extensions can be generated with:

```bash
mix pow.extension.phoenix.gen.templates --extension PowResetPassword --extension PowEmailConfirmation
```

Please follow the instructions in ["Modify templates"](#modify-templates) to enable customization of templates and views.

### Mailer support

Many extensions require a mailer to have been set up. Let's create a mailer mock module in  `WEB_PATH/pow_mailer.ex`:

```elixir
defmodule MyAppWeb.PowMailer do
  use Pow.Phoenix.Mailer
  require Logger

  def cast(%{user: user, subject: subject, text: text, html: html, assigns: _assigns}) do
    # Build email struct to be used in `process/1`

    %{to: user.email, subject: subject, text: text, html: html}
  end

  def process(email) do
    # Send email

    Logger.debug("E-mail sent: #{inspect email}")
  end
end
```

Update `config/config.ex` with `:mailer_backend` key:

```elixir
config :my_app, :pow,
  # ...
  mailer_backend: MyAppWeb.PowMailer
```

This mailer module will only output the mail to your log, so you can e.g. try out the reset password and email confirmation links. You should integrate the Pow mailer with your actual mailer system. For Swoosh integration, check out the [Swoosh mailer guide](guides/SWOOSH_MAILER.md).

#### Modify mailer templates

Since Phoenix doesn't ship with a mailer setup by default you should first modify `my_app_web.ex` with a `:mailer_view` macro:

```elixir
defmodule MyAppWeb do
  # ...

  def mailer_view do
    quote do
      use Phoenix.View, root: "lib/my_app_web/templates",
                        namespace: MyAppWeb

      use Phoenix.HTML
    end
  end

  # ...

end
```

Now generate the view and template files:

```bash
mix pow.extension.phoenix.mailer.gen.templates --extension PowResetPassword --extension PowEmailConfirmation
```

This will generate view files in `WEB_PATH/views/mailer/`, and html and text templates in `WEB_PATH/templates/mailer` directory.

Add `web_mailer_module: MyAppWeb` to the configuration so Pow will use the views you've just generated:

```elixir
config :my_app, :pow,
  # ...
  web_mailer_module: MyAppWeb
```

The generated view files contains the subject lines for the emails.

## Configuration

Pow is build to be modular, and easy to configure. The configuration is passed to method calls, and plug options and they will take priority over any environment configuration. It's ideal in case you got an umbrella app with multiple separate user domains.

The easiest way to use Pow with Phoenix is to use a `:otp_app` in method calls and set the app environment configuration. It will keep a persistent fallback configuration that you configure in one place.

### Module groups

Pow has three main groups of modules that each can used individually, or in conjunction with each other:

#### Pow.Plug

This group will handle the plug connection. The configuration will be assigned to `conn.private[:pow_config]` and passed through the controller to the users' context module. The Plug module has methods to authenticate, create, update, and delete users, and will generate/renew the session automatically.

#### Pow.Ecto

This group contains all modules related to the Ecto based user schema and context. By default, Pow will use the [`Pow.Ecto.Context`](lib/pow/ecto/context.ex) module to authenticate, create, update and delete users with lookups to the database. However, it's straightforward to extend or write your custom user context. You can do this by setting the `:users_context` configuration key.

#### Pow.Phoenix

This group contains the controllers, views, and templates for Phoenix. You only need to set the (session) plug in `endpoint.ex` and add the routes to `router.ex`. Views and templates are not generated by default, instead, the compiled views and templates in Pow are used. You can generate the templates used by running `mix pow.phoenix.gen.templates`. You can also customize flash messages and callback routes by creating your own using `:messsages_backend` and `:routes_backend`.

The registration and session controllers can be changed with your customized versions too, but since the routes are built on compile time, you'll have to set them up in `router.ex` with `:pow` namespace. For minor pre/post-processing of requests, you can use the `:controller_callbacks` option. It exists to make it easier to modify flow with extensions (e.g., send a confirmation email upon user registration).

### Pow.Extension

This module helps build extensions for Pow. There're three extension mix tasks to generate Ecto migrations and phoenix templates.

```bash
mix pow.extension.ecto.gen.migrations
```

```bash
mix pow.extension.phoenix.gen.templates
```

```bash
mix pow.extension.phoenix.mailer.gen.templates
```

### Authorization plug

Pow ships with a session plug module. You can easily switch it out with a different one. As an example, here's how you do that with [Guardian](https://github.com/ueberauth/guardian):

```elixir
defmodule MyAppWeb.Pow.Plug do
  use Pow.Plug.Base

  def fetch(conn, config) do
    user = MyApp.Guardian.Plug.current_resource(conn)

    {conn, user}
  end

  def create(conn, user, config) do
    conn = MyApp.Guardian.Plug.sign_in(conn, user)

    {conn, user}
  end

  def delete(conn, config) do
    MyApp.Guardian.Plug.signout(conn)
  end
end

defmodule MyAppWeb.Endpoint do
  # ...

  plug MyAppWeb.Pow.Plug, otp_app: :my_app
end
```

### Ecto changeset

The user module has a fallback `changeset/2` method. If you want to add custom validations, you can use the `pow_changeset/2` method like so:

```elixir
defmodule MyApp.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema

  schema "users" do
    field :custom, :string

    pow_user_fields()

    timestamps()
  end

  def changeset(user_or_changeset, attrs) do
    user
    |> pow_changeset(attrs)
    |> Ecto.Changeset.cast(attrs, [:custom])
    |> Ecto.Changeset.validate_required([:custom])
  end
end
```

### Phoenix controllers

Controllers in Pow are very slim and consists of just one `Pow.Plug` method call with response methods. If you wish to change the flow of the `RegistrationController` and `SessionController`, the best way is to create your own and modify `router.ex`.

However, to make it easier to integrate extension, you can add callbacks to the controllers that do some light pre/post-processing of the request:

```elixir
defmodule MyCustomExtension.Phoenix.ControllerCallbacks do
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, user, conn}, _config) do
    # send email

    {:ok, user, conn}
  end
end
```

You can add methods for `before_process` (before the action happens) and `before_respond` (before parsing the results from the action).

### I18n

All templates can be generated and modified to use your Gettext module.

For flash messages, you can create the following module:

```elixir
defmodule MyAppWeb.Pow.Messages do
  use Pow.Phoenix.Messages
  use Pow.Extension.Phoenix.Messages,
    extensions: [ResetPassword]

  import MyAppWeb.Gettext

  def user_not_authenticated(_conn), do: gettext("You need to sign in to see this page.")

  # Message methods for extensions has to be prepended with the snake cased
  # extension name. So the `email_has_been_sent/1` method from
  # `PowResetPassword` is written as `pow_reset_password_email_has_been_sent/1`
  # in your messages module.
  def pow_reset_password_email_has_been_sent(_conn), do: gettext("An email with reset instructions has been sent to you. Please check your inbox.")
end
```

Add `messages_backend: MyAppWeb.Pow.Messages` to your configuration. You can find all the messages in `Pow.Phoenix.Messages` and `[Pow Extension].Phoenix.Messages`.

### Callback routes

You can customize callback routes by creating the following module:

```elixir
defmodule MyAppWeb.Pow.Routes do
  use Pow.Phoenix.Routes
  alias MyAppWeb.Router.Helpers, as: Routes

  def after_sign_in_path(conn), do: Routes.some_path(conn, :index)
end
```

Add `routes_backend: MyAppWeb.Pow.Routes` to your configuration. You can find all the routes in `Pow.Phoenix.Routes`.

### Password hashing function

You can change the password hashing function easily. For example, this is how you use [comeonin](https://github.com/riverrun/comeonin) with Argon2:

```elixir
defmodule MyApp.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema,
    password_hash_methods: {&Comeonin.Argon2.hashpwsalt/1,
                            &Comeonin.Argon2.checkpw/2}

  # ...
end
```

### Logout link

You can use the following Phoenix link to add logout link to your Phoenix template:

```elixir
<%= link "Sign out", to: Routes.pow_session_path(@conn, :delete), method: :delete %>
```

## Plugs

### Pow.Plug.Session

Enables session based authorization. The user struct will be collected from a cache store through a GenServer using a unique token generated for the session. The token will be reset every time the authorization level changes (handled by `Pow.Plug`).

#### Cache store

By default [`Pow.Store.Backend.EtsCache`](lib/pow/store/backend/ets_cache.ex) is started automatically and can be used in development and test environment.

For a production environment, you should use a distributed, persistent cache store. Pow makes this easy with [`Pow.Store.Backend.MnesiaCache`](lib/pow/store/backend/mnesia_cache.ex). To start MnesiaCache in your Phoenix app, add it to your `application.ex` supervisor:

```elixir
defmodule MyAppWeb.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(MyAppWeb.Endpoint, []),
      worker(Pow.Store.Backend.MnesiaCache, [[nodes: [node()]]])
    ]

    opts = [strategy: :one_for_one, name: MyAppWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ...
end
```

Update the config `cache_store_backend: Pow.Store.Backend.MnesiaCache`.

### Pow.Plug.RequireAuthenticated

Will halt connection if no current user is not present in assigns. Expects an `:error_handler` option.

### Pow.Plug.RequireNotAuthenticated

Will halt connection if a current user is present in assigns. Expects an `:error_handler` option.

## Migrating from Coherence

If you're currently using Coherence, you can migrate your app to use Pow instead. Follow the instructions in [COHERENCE_MIGRATION.md](guides/COHERENCE_MIGRATION.md).

## Pow security practices

* The `user_id_field` value is always treated as case insensitive
* If the `user_id_field` is `:email`, it'll be validated based on RFC 5322 (excluding IP validation)
* The `:password` has a minimum length of 10 characters
* The `:password` has a maximum length of 4096 bytes [to prevent DOS attacks against Pbkdf2](https://github.com/riverrun/pbkdf2_elixir/blob/master/lib/pbkdf2.ex#L21)
* The `:password_hash` is generated with `PBKDF2-SHA512` with 100,000 iterations
* The session value contains a UUID token that is used to pull credentials through a GenServer
* The credentials are stored in a key-value cache with TTL of 30 minutes
* The credentials and session are renewed after 15 minutes if any activity is detected
* The credentials and session are renewed when user updates

Some of the above is based on [OWASP](https://www.owasp.org/) recommendations.

## Other libraries

[PowAssent](https://github.com/danschultzer/pow_assent) - Multi-provider support for Pow with strategies for Twitter, Github, Google, Facebook and more

## LICENSE

(The MIT License)

Copyright (c) 2018 Dan Schultzer & the Contributors Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

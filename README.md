# ![Pow](assets/logo-full.svg)

[![Github CI](https://github.com/danschultzer/pow/workflows/CI/badge.svg)](https://github.com/danschultzer/pow/actions?query=workflow%3ACI)
[![hexdocs.pm](https://img.shields.io/badge/api-docs-green.svg?style=flat)](https://hexdocs.pm/pow)
[![hex.pm](https://img.shields.io/hexpm/v/pow.svg?style=flat)](https://hex.pm/packages/pow)

Pow is a robust, modular, and extendable authentication and user management solution for Phoenix and Plug-based apps.

## Features

* User registration
* Session based authorization
* [Per Endpoint/Plug configuration](#configuration)
* [API token authorization](guides/api.md)
* Mnesia cache with automatic cluster healing
* [Multitenancy](guides/multitenancy.md)
* [User roles](guides/user_roles.md)
* [Extendable](#extensions)
* [I18n](#i18n)
* [And more](guides/why_pow.md)

## Installation

Add Pow to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    # ...
    {:pow, "~> 1.0.27"}
  ]
end
```

Run `mix deps.get` to install it.

## Getting started

### Phoenix app

**Umbrella project**: Check out the [umbrella project guide](guides/umbrella_project.md).

Install the necessary files:

```bash
mix pow.install
```

This will add the following files to your app:

```bash
LIB_PATH/users/user.ex
PRIV_PATH/repo/migrations/TIMESTAMP_create_users.ex
```

And also update the following files:

```bash
config/config.exs
WEB_PATH/endpoint.ex
WEB_PATH/router.ex
```

Run migrations with `mix setup`, start the server with `mix phx.server`, and you can now visit `http://localhost:4000/registration/new` to create a user.

### Modify templates

By default, Pow exposes as few files as possible.

If you wish to modify the templates, you can generate them (and the view files) using:

```bash
mix pow.phoenix.gen.templates
```

This will also add `web_module: MyAppWeb` to the configuration in `config/config.exs`.

## Extensions

Pow is made so it's easy to extend the functionality with your own complimentary library. The following extensions are included in this library:

* [PowResetPassword](lib/extensions/reset_password/README.md)
* [PowEmailConfirmation](lib/extensions/email_confirmation/README.md)
* [PowPersistentSession](lib/extensions/persistent_session/README.md)
* [PowInvitation](lib/extensions/invitation/README.md)

Check out the ["Other libraries"](#other-libraries) section for other extensions.

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

Add Pow extension routes to `WEB_PATH/router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router
  use Pow.Extension.Phoenix.Router,
    extensions: [PowResetPassword, PowEmailConfirmation]

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

Please follow the instructions in ["Modify templates"](#modify-templates) to ensure that your custom templates and views will be used.

### Mailer support

Many extensions require a mailer to have been set up. Let's create a mailer mock module in  `WEB_PATH/pow/mailer.ex`:

```elixir
defmodule MyAppWeb.Pow.Mailer do
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
  mailer_backend: MyAppWeb.Pow.Mailer
```

This mailer module will only output the mail to your log, so you can e.g. try out the reset password and email confirmation links. You should integrate the Pow mailer with your actual mailer system. For Swoosh or Bamboo integration, check out the [Configuring mailer guide](guides/configuring_mailer.md).

#### Modify mailer templates

Generate the view and template files:

```bash
mix pow.extension.phoenix.mailer.gen.templates --extension PowResetPassword --extension PowEmailConfirmation
```

This will generate view files in `WEB_PATH/views/POW_EXTENSION/mailer/`, and html and text templates in `WEB_PATH/templates/POW_EXTENSION/mailer/` directory. This will also add the necessary ` mailer_view/0` macro to `WEB_PATH/my_app_web.ex` and update the pow config with ``web_mailer_module: MyAppWeb`.

The generated view files contain the subject lines for the emails.

## Configuration

Pow is built to be modular, and easy to configure. The configuration is passed to function calls as well as plug options, and they will take priority over any environment configuration. It's ideal in case you got an umbrella app with multiple separate user domains.

The easiest way to use Pow with Phoenix is to use a `:otp_app` in function calls and set the app environment configuration. It will keep a persistent fallback configuration that you configure in one place.

### Module groups

Pow has three main groups of modules that each can be used individually, or in conjunction with each other:

#### Pow.Plug

This group will handle the plug connection. The configuration will be assigned to `conn.private[:pow_config]` and passed through the controller to the users' context module. The Plug module has functions to authenticate, create, update, and delete users, and will generate/renew the session automatically.

#### Pow.Ecto

This group contains all modules related to the Ecto based user schema and context. By default, Pow will use the `Pow.Ecto.Context` module to authenticate, create, update and delete users with lookups to the database. However, it's straightforward to extend or write your custom user context. You can do this by setting the `:users_context` configuration key.

#### Pow.Phoenix

This group contains the controllers, views, and templates for Phoenix. You only need to set the (session) plug in `endpoint.ex` and add the routes to `router.ex`. Views and templates are not generated by default, instead, the compiled views and templates in Pow are used. You can generate the templates used by running `mix pow.phoenix.gen.templates`. You can also customize flash messages and callback routes by creating your own using `:messages_backend` and `:routes_backend`.

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

Pow ships with a session plug module. You can easily switch it out with a different one. As an example, here's how you do that with `Phoenix.Token`:

```elixir
defmodule MyAppWeb.Pow.Plug do
  use Pow.Plug.Base

  @session_key :pow_user_token
  @salt "user salt"
  @max_age 86400

  def fetch(conn, config) do
    conn  = Plug.Conn.fetch_session(conn)
    token = Plug.Conn.get_session(conn, @session_key)

    MyAppWeb.Endpoint
    |> Phoenix.Token.verify(@salt, token, max_age: @max_age)
    |> maybe_load_user(conn)
  end

  defp maybe_load_user({:ok, user_id}, conn), do: {conn, MyApp.Repo.get(User, user_id)}
  defp maybe_load_user({:error, _any}, conn), do: {conn, nil}

  def create(conn, user, config) do
    token = Phoenix.Token.sign(MyAppWeb.Endpoint, @salt, user.id)
    conn  =
      conn
      |> Plug.Conn.fetch_session()
      |> Plug.Conn.put_session(@session_key, token)

    {conn, user}
  end

  def delete(conn, config) do
    conn
    |> Plug.Conn.fetch_session()
    |> Plug.Conn.delete_session(@session_key)
  end
end

defmodule MyAppWeb.Endpoint do
  # ...

  plug MyAppWeb.Pow.Plug, otp_app: :my_app
end
```

### Ecto changeset

The user module has a fallback `changeset/2` function. If you want to add custom validations, you can use the `pow_changeset/2` function like so:

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
    user_or_changeset
    |> pow_changeset(attrs)
    |> Ecto.Changeset.cast(attrs, [:custom])
    |> Ecto.Changeset.validate_required([:custom])
  end
end
```

### Phoenix controllers

Controllers in Pow are very slim and consists of just one `Pow.Plug` function call with response functions. If you wish to change the flow of the `Pow.Phoenix.RegistrationController` and `Pow.Phoenix.SessionController`, the best way is to create your own and modify `router.ex`.

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

You can add functions for `before_process/4` (before the action happens) and `before_respond/4` (before parsing the results from the action).

#### Testing with authenticated users

To test with authenticated users in your controller tests, you just have to assign the user to the conn in your setup callback:

```elixir
setup %{conn: conn} do
  user = %User{email: "test@example.com"}
  conn = Pow.Plug.assign_current_user(conn, user, otp_app: :my_app)

  {:ok, conn: conn}
end
```

### I18n

All templates can be generated and modified to use your Gettext module.

For flash messages, you can create the following module:

```elixir
defmodule MyAppWeb.Pow.Messages do
  use Pow.Phoenix.Messages
  use Pow.Extension.Phoenix.Messages,
    extensions: [PowResetPassword]

  import MyAppWeb.Gettext

  def user_not_authenticated(_conn), do: gettext("You need to sign in to see this page.")

  # Message functions for extensions has to be prepended with the snake cased
  # extension name. So the `email_has_been_sent/1` function from
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

`Pow.Ecto.Schema.Password` is used to hash and verify with Pbkdf2. It's highly recommended to lower the iterations count in your test environment to speed up your tests:

```elixir
config :pow, Pow.Ecto.Schema.Password, iterations: 1
```

You can change the password hashing function easily. For example, this is how you use [comeonin with Argon2](https://github.com/riverrun/argon2_elixir):

```elixir
defmodule MyApp.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema,
    password_hash_methods: {&Argon2.hash_pwd_salt/1,
                            &Argon2.verify_pass/2}

  # ...
end
```

### Current user and sign out link

You can use `Pow.Plug.current_user/1` to fetch the current user from the connection.

This can be used to show the sign in or sign out links in your Phoenix template:

```elixir
<%= if Pow.Plug.current_user(@conn) do %>
  <span><%= link "Sign out", to: Routes.pow_session_path(@conn, :delete), method: :delete %></span>
<% else %>
  <span><%= link "Register", to: Routes.pow_registration_path(@conn, :new) %></span>
  <span><%= link "Sign in", to: Routes.pow_session_path(@conn, :new) %></span>
<% end %>
```

The current user can also be fetched by using the template assigns set in the configuration with `:current_user_assigns_key` (defaults to `@current_user`).

## Plugs

### Pow.Plug.Session

Enables session-based authorization. The user struct will be collected from a cache store through a GenServer using a unique token generated for the session. The token will be reset every time the authorization level changes (handled by `Pow.Plug`) or after a certain interval (default 15 minutes).

The user struct fetched can be out of sync with the database if the row in the database is updated by actions outside Pow. In this case, it's recommended to [add a plug](guides/sync_user.md) that reloads the user struct and reassigns it to the connection.

Custom metadata can be set for the session by assigning a private `:pow_session_metadata` key in the conn. Read the `Pow.Plug.Session` module docs for more details.

#### Cache store

By default `Pow.Store.Backend.EtsCache` is started automatically and can be used in development and test environment.

For a production environment, you should use a distributed, persistent cache store. Pow makes this easy with `Pow.Store.Backend.MnesiaCache`. To start MnesiaCache in your Phoenix app, add it to your `application.ex` supervisor:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      MyAppWeb.Endpoint,
      Pow.Store.Backend.MnesiaCache
      # # Or in a distributed system:
      # {Pow.Store.Backend.MnesiaCache, extra_db_nodes: {Node, :list, []}},
      # Pow.Store.Backend.MnesiaCache.Unsplit # Recover from netsplit
    ]

    opts = [strategy: :one_for_one, name: MyAppWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ...
end
```

Update `config/config.ex` with `:cache_store_backend` key:

```elixir
config :my_app, :pow,
  # ...
  cache_store_backend: Pow.Store.Backend.MnesiaCache
```

Remember to add `:mnesia` to your `:extra_applications` so it'll be available for your release build. Mnesia will write files to the current working directory. The path can be changed with `config :mnesia, dir: '/path/to/dir'`.

The MnesiaCache requires write access. If you've got a read-only file system you should take a look at the [Redis cache backend store guide](guides/redis_cache_store_backend.md).

### Pow.Plug.RequireAuthenticated

Will halt connection if no current user is not present in assigns. Expects an `:error_handler` option.

### Pow.Plug.RequireNotAuthenticated

Will halt connection if a current user is present in assigns. Expects an `:error_handler` option.

## Migrating from Coherence

If you're currently using Coherence, you can migrate your app to use Pow instead. Follow the instructions in [Coherence migration guide](guides/coherence_migration.md).

## Pow security practices

See [security practices](guides/security_practices.md).

## Other libraries

[PowAssent](https://github.com/danschultzer/pow_assent) - Multi-provider support for Pow with strategies for Twitter, Github, Google, Facebook and more

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md).

## LICENSE

(The MIT License)

Copyright (c) 2018-2019 Dan Schultzer & the Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Pow

[![Build Status](https://travis-ci.org/danschultzer/pow.svg?branch=master)](https://travis-ci.org/danschultzer/pow) [![hex.pm](http://img.shields.io/hexpm/v/pow.svg?style=flat)](https://hex.pm/packages/pow)

Pow is a powerful, modular, and extendable authentication and user management solution for Phoenix and Plug based apps.

## Features

* User registration
* Session based authorization
* Per Endpoint/Plug configuration
* Extendable
* I18n

## Installation

Add Pow to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # ...
    {:pow, "~> 0.1"}
    # ...
  ]
end
```

Run `mix deps.get` to install it.

## Getting started (Phoenix)

Install the necessary files:

```bash
mix pow.install
```

This will add the following files to your app:

```bash
LIB_PATH/users/user.ex
PRIV_PATH/repo/migrations/TIMESTAMP_create_user.ex
```

Update `config/config.ex` with the following:

```elixir
config :my_app_web, :pow,
  user: MyApp.Users.User,
  repo: MyApp.Repo
```

Set up `WEB_PATH/endpoint.ex` to enable session based authentication:

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app_web

  # ...

  plug Plug.Session,
    store: :cookie,
    key: "_my_project_demo_key",
    signing_salt: "secret"

  plug Pow.Plug.Session, otp_app: :my_app_web

  # ...
end
```

Add Pow routes to `WEB_PATH/router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router

  # ...

  pipeline :protected do
    plug Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
  end

  scope "/" do
    pipe_through :browser

    pow_routes()
  end

  # ...

  scope "/", MyAppWeb do
    pipe_through [:browser, :protected]

    # Protected routes ...
  end
end
```

That's it! Run `mix ecto.setup`, and you can now visit `http://localhost:4000/registrations/new`, and create a new user.

By default, Pow will only expose files that are absolutely necessary

 If you wish to modify the templates, you can generate them (and the view files) using: `mix pow.phoenix.gen.templates`. Remember to add `web_module: MyAppWeb` to the configuration.

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

Update `config/config.ex` with the `:extensions`and `:controller_callbacks` key:

```elixir
config :my_app_web, :pow,
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
    |> pow_extensions_changeset(attrs)
  end
end
```

Add Pow extension routes to `WEB_PATH/router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router
  use Pow.Extension.Phoenix.Router, otp_app: :my_app_web

  # ...

  scope "/" do
    pipe_through :browser

    pow_routes()
    pow_extension_routes()
  end

  # ...
end
```

### Mailer support

Many extensions requires a mailer to have been set up. Let's create the mailer in `WEB_PATH/mailer.ex` using [swoosh](https://github.com/swoosh/swoosh):

```elixir
defmodule MyAppWeb.Mailer do
  use Pow.Phoenix.Mailer
  use Swoosh.Mailer, otp_app: :my_app_web
  import Swoosh.Email

  def cast(%{user: user, subject: subject, text: text, html: html}) do
    %Swoosh.Email{}
    |> to({"", email.user.email})
    |> from({"My App", "myapp@example.com"})
    |> subject(subject)
    |> html_body(html)
    |> text_body(text)
  end

  def process(email) do
    deliver(email)
  end
end
```

Update `config/config.ex` with `:mailer_backend` key:

```elixir
config :my_app_web, :pow,
  user: MyApp.Users.User,
  repo: MyApp.Repo,
  extensions: [PowResetPassword, PowEmailConfirmation],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  mailer_backend: MyAppWeb.Mailer
```

That's it!

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
mix pow.extension.phoenix.mailer.gen.templates
```

This will generate view files in `WEB_PATH/views/mailer/`, and html and text templates in `WEB_PATH/templates/mailer` directory.

Add `web_mailer_module: MyAppWeb` to the configuration, and you're set!

## Configuration

Pow is build to be modular, and easy to configure. Configuration is primarily passed through method calls, and plug options and they will take priority over any environment configuration. This is ideal in case you've an umbrella app with multiple separate user domains.

The easiest way to use Pow with Phoenix is to use a `:otp_app` in method calls, and set the app environment configuration. This will keep a persistent fallback configuration that you configure in one place.

### Module groups

Pow has three main groups of modules that each can used individually, or in conjunction with each other:

#### Pow.Plug

This group will handle the plug connection. The configuration will be assigned to `conn.private[:pow_config]` and passed through the controller to the users context module. The Plug module have methods to authenticate, create, update, and delete users, and will generate/renew the session automatically.

#### Pow.Ecto

This group contains all modules related to the Ecto based user schema and context. By default, Pow will use the [`Pow.Ecto.Context`](lib/pow/ecto/context.ex) module to authenticate, create, update and delete users with lookups to the database. However, it's very simple to extend, or write your own user context. You can do this by setting the `:users_context` configuration key.

#### Pow.Phoenix

This contains the controllers, views and templates for Phoenix. You only need to set the (session) plug in `endpoint.ex` and add the routes to `router.ex`. Views and templates are not generated by default, but instead the compiled views and templates in Pow will be used. You can generate the templates used by running `mix pow.phoenix.gen.templates`. Flash messages and routes can also be customized by creating your own using `:messsages_backend` and `:routes_backend`.

The registration and session controllers can be changed with your customized versions too, but since the routes are build on compile time, you'll have to set them up in `router.ex` with `:pow` namespace. For minor pre/post-processing of requests you can use the `:controller_callbacks` option. It exist to make it easier modify flow with extensions (e.g. send a confirmation email upon user registration).

### Pow.Extension

This module helps build extensions for Pow. There're three extension mix tasks to generate ecto migrations and phoenix templates.

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

  plug MyAppWeb.Pow.Plug, otp_app: :my_app_web
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

Controllers in Pow are very slim, and consists of just one `Pow.Plug` method call, and then response/render handling. If you wish to change the flow of the `RegistrationController` and `SessionController`, the best way is to simply create your own and modify `router.ex`.

However, to make it easier to integrate extension, you can add callbacks to the controllers that does some light pre/post-processing of the request:

```elixir
defmodule MyCustomExtension.Pow.ControllerCallbacks do
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

  def pow_reset_password_email_has_been_sent(_conn), do: gettext("An email with reset instructions has been sent to you. Please check your inbox.")
end
```

Add `messages_backend: MyAppWeb.Pow.Messages` to your configuration. You can find the all messages in `Pow.Phoenix.Messages` and `[Pow Extension].Phoenix.Messages`.

## Plugs

### Pow.Plug.Session

Enables session based authorization. The user struct will be collected from a cache store through a GenServer using a unique token generated for the session. The token will be reset every time the authorization level changes (handled by `Pow.Plug`).

#### Cache store

By default [`Pow.Store.Backend.EtsCache`](lib/pow/store/backend/ets_cache.ex) is started automatically and can be used in development and test environment.

For production environment a distributed, persistent cache store should be used. Pow makes this easy with [`Pow.Store.Backend.MnesiaCache`](lib/pow/store/backend/mnesia_cache.ex). As an example, to start MnesiaCache in your Phoenix app, you just have to set up your `application.ex`:

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

Will halt connection if no current user is not found in assigns. Expects an `:error_handler` option.

### Pow.Plug.RequireNotAuthenticated

Will halt connection if a current user is found in assigns. Expects an `:error_handler` option.

## Migrating from Coherence

If you're currently using Coherence, you can migrate your app to use Pow instead.

First we'll remove coherence.

  1. Remove `:coherence` config from `config/config.exs` (also any coherence config in `config/dev.exs`, `config/prod.exs` and `config/test.exs`)
  2. Delete `coherence_messages.ex`, `coherence_web.ex`, `coherence/redirects.ex`, `emails/coherence`, `templates/coherence`, and `views/coherence`.
  3. Remove coherence from `user.ex`. This includes the coherence specific changeset method `def changeset(model, params, :password)`, and the `:email` field in schema.
  4. Remove coherence from `router.ex`. Pipeline `:public` can be removed entirely if it's only used for coherence, as well as scopes that only contains coherence routes.
  5. Remove `:coherence` from `mix.exs` and run `mix deps.unlock coherence`

Next we'll add in Pow.

Set up a migration file with the following change to continue using your users table:

  ```elixir
  def up do
    alter table(:users) do
      add :email_confirmation_token, :string
      add :email_confirmed_at,       :utc_datetime
      add :unconfirmed_email,        :string
    end

    create unique_index(:users, :email_confirmation_token)
  end

  def down do
    alter table(:users) do
      remove :email_confirmation_token
      remove :email_confirmed_at
      remove :unconfirmed_email
    end
  end
  ```

Add configuration:

```elixir
config :my_app_web, :pow,
  repo: MyApp.Repo,
  user: MyApp.User,
  extensions: [PowEmailConfirmation, PowResetPassword],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  mailer_backend: MyAppWeb.Mailer
```

Set up `user.ex` to use Pow:

  ```elixir
  defmodule MyApp.User do
    use Ecto.Schema
    use Pow.Ecto.Schema
    use Pow.Extension.Ecto.Schema,
      extensions: [PowEmailConfirmation, PowResetPassword]

    schema "users" do
      # ...

      pow_user_fields()

      timestamp()
    end

    # ...

    @spec changeset(t(), map()) :: Changeset.t()
    def changeset(model, params \\ %{}) do
      model
      |> cast(params, [:email])
      |> pow_changeset(params)
      |> pow_extension_changeset(params)
    end
  end
  ```

Coherence uses bcrypt, so you'll have to switch to bcrypt in Pow:

 1. Install comeonin for bcrypt in `mix.exs`:
    ```elixir
    {:comeonin, "~> 3.0"}
    ```

 2. Set up `user.ex` to use bcrypt for password hashing:

    ```elixir
    defmodule MyApp.User do
      use Ecto.Schema
      use MyApp.Pow.Ecto.Schema,
        password_hash_methods: {&Comeonin.Bcrypt.hashpwsalt/1,
                                &Comeonin.Bcrypt.checkpw/2}

      # ...
    end
    ```

Set up `mailer.ex` to enable emails:

  ```elixir
  defmodule MyAppWeb.Mailer do
    @moduledoc false
    use Pow.Phoenix.Mailer
    use Swoosh.Mailer, otp_app: :my_app_web
    import Swoosh.Email

    def cast(email) do
      new()
      |> from({"My App", "myapp@example.com"})
      |> to({"", email.user.email})
      |> subject(email.subject)
      |> text_body(email.text)
      |> html_body(email.html)
    end

    def process(email), do: deliver(email)
  end
  ```

Add session plug to `endpoint.ex`:

  ```elixir
  # After plug Plug.Session

  plug MyApp.Pow.Plug.Session, otp_app: :my_app_web
  ```

Set up `routes.ex`

  ```elixir
  defmodule MyAppWeb.Router do
    use Phoenix.Router
    use Pow.Phoenix.Router
    use Pow.Extension.Phoenix.Router, otp_app: :my_app_web

    # ...

    pipeline :protected do
      plug Pow.Plug.RequireAuthenticated,
        error_handler: Pow.Phoenix.PlugErrorHandler
    end

    scope "/" do
      pipe_through :browser

      pow_routes()
      pow_extension_routes()
    end

    # ...
  end
  ```

Change `Routes.session_path` to `Routes.pow_session_path`, and
`Routes.registration_path` to `Routes.pow_registration_path`. Any references to `Coherence.current_user/1`, can be changed to `Pow.Plug.current_user/1`.

That's it! You can now test out your Pow'ered app, and then remove all unused fields/tables after.

### Keep confirmed_at and confirmation_token data

To keep confirmed_at and confirmation_token data from your past coherence setup, you should first add the coherence fields to your user schema:

```elixir
field :confirmation_token, :string
field :confirmed_at, :utc_datetime
```

And then you can run the following:

```elixir
alias MyApp.{User, Repo}

User
|> Repo.all()
|> Enum.each(fn user ->
  user
  |> Ecto.Changeset.change(%{
    email_confirmation_token: user.confirmation_token,
    email_confirmed_at: user.confirmed_at
    })
  |> Repo.update!()
end)
```

## Pow security practices

* The `user_id_field` value is always treated as case insensitve
* If the `user_id_field` is `:email`, it'll be validated based on RFC 5322 (excluding IP validation)
* The `:password` has a minimum length of 10 characters
* The `:password` has a maximum length of 4096 bytes [to prevent DOS attacks against Pbkdf2](https://github.com/riverrun/pbkdf2_elixir/blob/master/lib/pbkdf2.ex#L21)
* The `:password_hash` is generated with `Pbpdf2`
* The session value contains a UUID token that is used to pull credentials through a GenServer
* The credentials are stored in a key-value storage with ttl of 30 minutes
* The credentials and session are renewed after 15 minutes if activity is detected
* The credentials and session are renewed when user updates

Some of the above is based on [https://www.owasp.org/](OWASP) recommendations.

## LICENSE

(The MIT License)

Copyright (c) 2018 Dan Schultzer & the Contributors Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

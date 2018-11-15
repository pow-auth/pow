# Custom controllers

## Introduction

Pow let you add an easy way to register and manage sessions for your users. However, sometimes you need more flexibility. For instance, you may need to protect the registration process. Pow allows you to build those kinds of apps. In this guide, we'll see the extra steps needed to achieve this goal. The code examples can be used as a starter pack. This guide was tested on a new Phoenix 1.4-rc3 app. You'll need PostgreSQL running and you need to make the adjustments to connect the db to the app.

## First steps

We need a new app
```
mix phx.new my_app
```

Let's add pow as a dependency, we'll use the phoenix-1.4 branch as phoenix 1.4 is still in rc.

```
defp deps do
  [
    {:phoenix, "~> 1.4.0-rc"},
    {:phoenix_pubsub, "~> 1.1"},
    {:phoenix_ecto, "~> 3.5"},
    {:ecto, "~> 3.0-rc", override: true},
    {:ecto_sql, "~> 3.0-rc", override: true},
    {:postgrex, ">= 0.0.0-rc"},
    {:phoenix_html, "~> 2.11"},
    {:phoenix_live_reload, "~> 1.2-rc", only: :dev},
    {:gettext, "~> 0.11"},
    {:jason, "~> 1.0"},
    {:plug_cowboy, "~> 2.0"},
    {:pow, git: "https://github.com/danschultzer/pow", branch: "phoenix-1.4"} #add this line
  ]
end
```

Install your deps

```
mix deps.get
```

If you don't have a user model you can easily run `mix pow.install` to get one. If you already have one verify that you had the equivalent of this migration:

```
defmodule MyApp.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :password_hash, :string

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
```

Change your config (`config/config.exs`) according to the pow first steps guide:

```
config :my_app, :pow,
  user: MyApp.Accounts.User,
  repo: MyApp.Repo
```
Note that we're working with an `Accounts` context (this is optional).

Finally we'll need to update our `my_app_web/endpoint.ex` to enable session based authentication:

```
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

## Start your customization process

### let's add some routes for our app

This will help us to get an overview of our app:

```
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # Not needed as we're making our routes
  # use Pow.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :protected do
    plug Pow.Plug.RequireRegistrationenticated,
      error_handler: MyAppWeb.AuthErrorHandlerController
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/signup", RegistrationController, :new
    post "/signup", RegistrationController, :create, as: :signup
    get "/login", SessionsController, :new, as: :login
    post  "/login", SessionsController, :create, as: :login
    delete "/logout", SessionsController, :delete, as: :logout

  end

  scope "/admin", MyAppWeb do
    pipe_through [:browser, :protected]
    get "private", PageController, :you_should_be_logged_to_see_this
  end
end
```

Note that we've made a pipeline called `protected` which ensure that the routes using it require the users to be authenticated first.

The other routes are the classic login/signup/logout.

Finally we've scoped an admin section with a protected page for test purposes.

### Add the controllers

As seen in the router we need a Registration and a Sessions controller. The names of the controller are not important, you can rename them as you want/need.

`my_app_web/controllers/registration_controller.ex` will let us create our users.

```
defmodule MyAppWeb.RegistrationController do
  use MyAppWeb, :controller
  alias MyApp.Accounts

  def new(conn, _params) do
    # you can use a classic phoenix way of doing things if you want
    # changeset = Accounts.User.custom_changeset(%Accounts.User{}, %{})

    # We'll leveraged the plug given by pow for now
    changeset = Pow.Plug.change_user(conn)
    conn
    |> assign(:new_user, changeset)
    |> render("new.html")
  end

  def create(conn, %{"user" => user_params}) do
    # This would work too but we'll rely again on Pow.Plug
    # new_user = %Accounts.User{}
    # |> Accounts.User.custom_changeset(user_params)
    # |> MyApp.Repo.insert()

    new_user = Pow.Plug.create_user(conn, user_params)

    case new_user do
      {:ok, user, %Plug.Conn{} = conn} ->
        conn
        |> put_flash(:info, "user created")
        |> redirect(to: Routes.page_path(conn, :you_should_be_logged_to_see_this))

      {:error, %Ecto.Changeset{} = changeset, %Plug.Conn{} = conn} ->
        render(conn, "new.html", new_user: changeset)

    end

  end

end
```

As you see we let `Pow.Plug` doing the hard work and wait for a response to continue.

We'll do the same in our `my_app_web/controllers/sessions_controller.ex`

```
defmodule MyAppWeb.SessionsController do
  use MyAppWeb, :controller
  alias MyApp.Accounts

  def new(conn, _params) do
    changeset = Pow.Plug.change_user(conn)

    conn
    |> render("login.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Pow.Plug.authenticate_user(conn, user_params) do
      {:ok, conn} ->
        conn
        |> put_flash(:info, "welcome back")
        |> redirect(to: Routes.page_path(conn, :you_should_be_logged_to_see_this))

      {:error, conn} ->
        changeset = Pow.Plug.change_user(conn, conn.params["user"])
        conn
        |> put_flash(:info, "Email or Password incorect")
        |> render( "login.html", changeset: changeset )
    end
  end

  def delete(conn, _params) do
    case Pow.Plug.clear_authenticated_user(conn) do
      {:ok, conn} ->
        redirect(conn, to: Routes.page_path(conn, :index))
    end
  end
end
```

Finally we need an error handler (we mentioned it in the router), we can't really use the one given by Pow as we need to use our new controllers.

`my_app_web/controllers/auth_error_handler_controller.ex`

```
defmodule MyAppWeb.AuthErrorHandlerController do
  use MyAppWeb, :controller
  alias Plug.Conn

  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, :not_authenticated) do
    conn
    |> put_flash(:error, "This is a private area your should log first")
    |> redirect(to: Routes.login_path(conn, :new))
  end
end
```

We just override the function `call(conn, :not_authenticated)` to redirect to our login page with a flash message. We should do the same for the function `call(conn, :already_authenticated)`.

### Overview of accounts/user.ex

`user.ex`

```
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  use Pow.Ecto.Schema

  schema "users" do
    pow_user_fields()
    field :first_name, :string
    field :last_name, :string

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> pow_changeset(attrs)
    |> cast(attrs, [:first_name, :last_name])
    |> validate_required([:first_name, :last_name])
  end

  # similar to the changeset above, we just want to underline
  # the fact that you can work with your custom changesets if needed.
  def custom_changeset(user, attrs) do
    user
    |> pow_changeset(attrs)
    |> cast(attrs, [:first_name, :last_name])
    |> validate_required([:first_name, :last_name])
  end
end
```

The only important line is `|> pow_changeset(attrs)` this is where we're telling our app to use the fields required by Pow.
Note that we've added the `first_name` and `last_name` fields to test it, if you want to do the same you'll need a migration to add those.


### Let's make some views and templates

Here are the snippets for the html templates you need. As the views are empty I'm not pasting them here.

`my_app_web/templates/registration/new.html.eex`

```
<%= form_for @new_user, Routes.signup_path(@conn, :create), [], fn f -> %>
  <%= label f, :first_name, "First name" %>
  <%= text_input f, :first_name %>
  <%= error_tag f, :first_name %>

  <%= label f, :last_name, "Last name" %>
  <%= text_input f, :last_name %>
  <%= error_tag f, :last_name %>

  <%= label f, :email, "email" %>
  <%= email_input f, :email %>
  <%= error_tag f, :email %>

  <%= label f, :password, "password" %>
  <%= password_input f, :password %>
  <%= error_tag f, :password %>

  <%= label f, :confirm_password, "confirm_password" %>
  <%= password_input f, :confirm_password %>
  <%= error_tag f, :confirm_password %>

  <%= submit "Create user" %>
<% end %>
```

`my_app_web/templates/sessions/new.html.eex`

```
<h2>loggin please</h2>

<%= form_for @changeset, Routes.login_path(@conn, :create), fn f -> %>
  <%= text_input f, :email %>
  <%= password_input f, :password %>
  <%= submit "Log in" %>
<% end %>
```

## Conclusion

That's all to start your custom pow powered app! You can run your server and test it.
Don't forget to create your private page (mentioned in the routes).

Remember that Pow allows you to leverage the power of its plugs. I strongly encourage you to read their documentation. That's the only things you'll need to customize the registration/session part of your app with pow!

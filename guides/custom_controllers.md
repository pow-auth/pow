# Custom controllers

_Please note that if you just wish to modify the templates, then you should follow the [Modify templates](../README.md#modify-templates) section(s) in the README. This guide is meant for allowing complete control over flow._

Pow makes it easy to use custom controllers leveraging the underlying Pow logic. It is ideal for cases where you need to control the flow, e.g., protect the registration process in a certain way.

First you should follow the [Getting Started](../README.md#getting-started) section in README until before the `router.ex` modification.

## Routes

Modify your `WEB_PATH/router.ex` to set up the Pow plugs in `:protected` and `:not_authenticated` pipelines with a custom error handler, and add the routes for your custom session and registration controllers:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # ... pipelines

  pipeline :protected do
    plug Pow.Plug.RequireAuthenticated,
      error_handler: MyAppWeb.AuthErrorHandler
  end

  pipeline :not_authenticated do
    plug Pow.Plug.RequireNotAuthenticated,
      error_handler: MyAppWeb.AuthErrorHandler
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :not_authenticated]

    get "/signup", RegistrationController, :new, as: :signup
    post "/signup", RegistrationController, :create, as: :signup
    get "/login", SessionController, :new, as: :login
    post "/login", SessionController, :create, as: :login
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :protected]

    delete "/logout", SessionController, :delete, as: :logout
  end

  # ... routes
end
```

And create `WEB_PATH/auth_error_handler.ex`:

```elixir
defmodule MyAppWeb.AuthErrorHandler do
  use MyAppWeb, :controller
  alias Plug.Conn

  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, :not_authenticated) do
    conn
    |> put_flash(:error, "You've to be authenticated first")
    |> redirect(to: Routes.login_path(conn, :new))
  end

  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, :already_authenticated) do
    conn
    |> put_flash(:error, "You're already authenticated")
    |> redirect(to: Routes.page_path(conn, :index))
  end
end
```

This module will make sure that unauthenticated user can't log out, and authenticated users can't sign in again.

### Controllers

We'll be using `Pow.Plug` for the heavy lifting, and customizing the response handling in our controllers.

Create `WEB_PATH/controllers/registration_controller.ex`:

```elixir
defmodule MyAppWeb.RegistrationController do
  use MyAppWeb, :controller

  def new(conn, _params) do
    # We'll leverage `Pow.Plug`, but you can also follow the classic Phoenix way:
    # changeset = MyApp.Users.User.changeset(%MyApp.Users.User{}, %{})

    changeset = Pow.Plug.change_user(conn)

    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    # We'll leverage `Pow.Plug`, but you can also follow the classic Phoenix way:
    # user =
    #   %MyApp.Users.User{}
    #   |> MyApp.Users.User.changeset(user_params)
    #   |> MyApp.Repo.insert()

    conn
    |> Pow.Plug.create_user(user_params)
    |> case do
      {:ok, user, conn} ->
        conn
        |> put_flash(:info, "Welcome!")
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, changeset, conn} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
```

Create `WEB_PATH/controllers/session_controller.ex`:

```elixir
defmodule MyAppWeb.SessionController do
  use MyAppWeb, :controller

  def new(conn, _params) do
    changeset = Pow.Plug.change_user(conn)

    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    conn
    |> Pow.Plug.authenticate_user(user_params)
    |> case do
      {:ok, conn} ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, conn} ->
        changeset = Pow.Plug.change_user(conn, conn.params["user"])

        conn
        |> put_flash(:info, "Invalid email or password")
        |> render("new.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    conn
    |> Pow.Plug.delete()
    |> redirect(to: Routes.page_path(conn, :index))
  end
end
```

### Templates

Create `WEB_PATH/templates/registration/new.html.eex`:

```elixir
<%= form_for @changeset, Routes.signup_path(@conn, :create), fn f -> %>
  <%= label f, :email %>
  <%= email_input f, :email %>
  <%= error_tag f, :email %>

  <%= label f, :password %>
  <%= password_input f, :password %>
  <%= error_tag f, :password %>

  <%= label f, :password_confirmation %>
  <%= password_input f, :password_confirmation %>
  <%= error_tag f, :password_confirmation %>

  <%= submit "Register" %>
<% end %>
```

Create `WEB_PATH/templates/session/new.html.eex`:

```elixir
<h1>Log in</h1>

<%= form_for @changeset, Routes.login_path(@conn, :create), fn f -> %>
  <%= text_input f, :email %>
  <%= password_input f, :password %>
  <%= submit "Log in" %>
<% end %>
```

Remember to create the view files `WEB_PATH/views/registration_view.ex` and `WEB_PATH/views/session_view.ex` too.

## Further customization

That's all you need to do to have custom controllers with Pow! From here on you can customize your flow.

You may want to utilize some of the extensions, but since you have created a custom controller, it's highly recommended that you do not rely on any controller actions in the extensions. Instead, you should implement the logic yourself to keep your controllers as explicit as possible. This is only an example:

```elixir
defmodule MyAppWeb.SessionController do
  # ...

  def create(conn, %{"user" => user_params}) do
    conn
    |> Pow.Plug.authenticate_user(user_params)
    |> verify_confirmed()
  end

  defp verify_confirmed({:ok, conn}) do
    conn
    |> Pow.Plug.current_user()
    |> email_confirmed?()
    |> case do
      true ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: Routes.page_path(conn, :index))

      false ->
        conn
        |> Pow.Plug.delete()
        |> put_flash(:info, "Your e-mail address has not been confirmed.")
        |> redirect(to: Routes.login_path(conn, :new))
    end
  end
  defp verify_confirmed({:error, conn}) do
    changeset = Pow.Plug.change_user(conn, conn.params["user"])

    conn
    |> put_flash(:info, "Invalid email or password")
    |> render("login.html", changeset: changeset)
  end

  defp email_confirmed?(%{email_confirmed_at: nil, email_confirmation_token: token, unconfirmed_email: nil}) when not is_nil(token), do: false
  defp email_confirmed?(_user), do: true
  # ...
end
```

# Custom controllers

Pow makes it easy to use custom controllers leveraging the underlying Pow logic. It is ideal for cases where you need to control the flow, e.g., protect the registration process in a certain way.

First you should follow the [Getting Started](../README.md#getting-started-phoenix) section in README until before the `router.ex` modification.

## Routes

Modify your `my_app_web/router.ex` to use your custom session and registration controllers instead of the default Pow controllers:

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
    get "/login", SessionsController, :new, as: :login
    post "/login", SessionsController, :create, as: :login
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :protected]

    delete "/logout", SessionsController, :create, as: :logout
  end

  # ... routes
end
```

And create `my_app_web/auth_error_handler.ex`:

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

Create `my_app_web/controllers/registration_controller.ex`:

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

Create `my_app_web/controllers/session_controller.ex`:

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
        |> render("login.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, conn} = Pow.Plug.clear_authenticated_user(conn)

    redirect(conn, to: Routes.page_path(conn, :index))
  end
end
```

### Templates

Create `my_app_web/templates/registration/new.html.eex`:

```elixir
<%= form_for @changeset, Routes.signup_path(@conn, :create), fn f -> %>
  <%= label f, :email, "email" %>
  <%= email_input f, :email %>
  <%= error_tag f, :email %>

  <%= label f, :password, "password" %>
  <%= password_input f, :password %>
  <%= error_tag f, :password %>

  <%= label f, :confirm_password, "confirm_password" %>
  <%= password_input f, :confirm_password %>
  <%= error_tag f, :confirm_password %>

  <%= submit "Register" %>
<% end %>
```

Create `my_app_web/templates/session/new.html.eex`:

```elixir
<h2>loggin please</h2>

<%= form_for @changeset, Routes.login_path(@conn, :create), fn f -> %>
  <%= text_input f, :email %>
  <%= password_input f, :password %>
  <%= submit "Log in" %>
<% end %>
```

Remember to create the view files `my_app_web/views/registration_view.ex` and `my_app_web/views/session_view.ex` too.

## Conclusion

That's all you need to do to have custom controllers with Pow! From here on you can customize your flow.
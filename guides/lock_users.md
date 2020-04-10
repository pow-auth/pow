# How to lock users

Locking users is trivial, and you won't need an extension for this. It can be done in several ways, but we'll work with the most straight forward setup.

## Update your schema

Add a `locked_at` column to your user schema, and a `lock_changeset/1` method to lock the account:

```elixir
defmodule MyApp.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  
  alias Ecto.Changeset

  schema "users" do
    field :locked_at, :utc_datetime

    pow_user_fields()

    timestamps()
  end

  @spec lock_changeset(Ecto.Schema.t() | Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def lock_changeset(user_or_changeset) do
    changeset = Changeset.change(user_or_changeset)
    locked_at = DateTime.from_unix!(System.system_time(:second), :second)

    case changeset do
      %{data: %{locked_at: nil}} -> Changeset.change(changeset, locked_at: locked_at)
      changeset -> changeset
    end
  end
end
```

Add a lock action to your user context module:

```elixir
defmodule MyApp.Users do
  alias MyApp.Users.User

  @spec lock(map()) :: {:ok, map()} | {:error, map()}
  def lock(user) do
    user
    |> User.lock_changeset()
    |> Repo.update()
  end
end
```

## Set up controller

Create or modify you user management controller so you (likely the admin) can lock the account:

```elixir
defmodule MyAppWeb.Admin.UserController do
  use MyAppWeb, :controller

  plug :load_user when action in [:delete]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(%{assigns: %{user: user}} = conn, _params) do
    case MyApp.Users.lock(user) do
      {:ok, _user} -> # User has been locked
      {:error, _changeset} -> # Something went wrong
    end
  end

  defp load_user(%{params: %{"id" => user_id}} = conn, _opts) do
    config = Pow.Plug.fetch_config(conn)

    case Pow.Operations.get_by([id: user_id], config) do
      nil -> # Invalid user id
      user -> Plug.Conn.assign(conn, :user, user)
    end
  end
end
```

Remember to add this route to your `router.ex` file.

## Prevent sign in for locked users

This is all you need to ensure locked users can't sign in:

```elixir
defmodule MyAppWeb.EnsureUserNotLockedPlug do
  @moduledoc """
  This plug ensures that a user isn't locked.

  ## Example

      plug MyAppWeb.EnsureUserNotLockedPlug
  """
  import Plug.Conn, only: [halt: 1]

  alias MyAppWeb.Router.Helpers, as: Routes
  alias Phoenix.Controller
  alias Plug.Conn
  alias Pow.Plug

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    conn
    |> Plug.current_user()
    |> locked?()
    |> maybe_halt(conn)
  end

  defp locked?(%{locked_at: locked_at}) when not is_nil(locked_at), do: true
  defp locked?(_user), do: false

  defp maybe_halt(true, conn) do
    conn
    |> Plug.delete()
    |> Controller.put_flash(:error, "Sorry, your account is locked.")
    |> Controller.redirect(to: Routes.pow_session_path(conn, :new))
    |> halt()
  end
  defp maybe_halt(_any, conn), do: conn
end
```

Add `plug MyAppWeb.EnsureUserNotLockedPlug` to your endpoint or pipeline, and presto!

## Optional: PowResetPassword

The above will prevent any locked users access, but it doesn't prevent them from using features that doesn't require authentication such as resetting their password. Be advised that this is a entirely optional step as this only affects UX.

While there are many different ways of handling this, the most explicit one is to simply override the logic entirely with a custom controller:

```elixir
defmodule MyAppWeb.ResetPasswordController do
  use MyAppWeb, :controller

  alias PowResetPassword.{Phoenix.ResetPasswordController, Plug, ResetTokenCache}

  def create(conn, params) do
    conn
    |> ResetPasswordController.process_create(params)
    |> maybe_halt()
    |> ResetPasswordController.respond_create()
  end

  defp maybe_halt({:ok, %{token: token, user: %{locked_at: locked_at}}, conn}) when not is_nil(locked_at) do
    user = Plug.change_user(conn)

    expire_token(conn, token)

    {:error, %{user | action: :update}, conn}
  end
  defp maybe_halt(response), do: response

  defp expire_token(conn, token) do
    backend =
      conn
      |> Pow.Plug.fetch_config()
      |> Pow.Config.get(:cache_store_backend, Pow.Store.Backend.EtsCache)

    ResetTokenCache.delete([backend: backend], token)
  end
end
```

To make the code simpler for us we're leveraging the methods from `PowResetPassword.Phoenix.ResetPasswordController` here.

Now all we got to do is to catch the route before the `pow_extension_routes/0` call:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router
  use Pow.Extension.Phoenix.Router, otp_app: :my_app

  # ...

  scope "/", MyAppWeb do
    pipe_through :browser

    post "/reset-password", ResetPasswordController, :create
  end

  scope "/" do
    pow_routes()
    pow_extension_routes()
  end

  # ...
end
```
# How to lock users

Locking users is trivial, and you won't need an extension for this. It can be done in several ways, but we'll work with the most straight forward setup.

## Update your schema

Add a `locked_at` column to your user schema, and a changeset to lock the account:

```elixir
defmodule MyApp.Users.User do
  # ...
  alias Ecto.Changeset

  schema "users" do
    field :locked_at, :utc_datetime

    pow_user_fields()

    timestamp()
  end

  # ...

  @spec lock_changeset(map()) :: map()
  def lock_changeset(user_or_changeset) do
    changeset = Changeset.change(user_or_changeset)
    locked_at = DateTime.from_unix!(System.system_time(:second), :second)

    case changeset do
      %{data: %{locked_at: nil}} -> Changeset.change(changeset, [locked_at: locked_at])
      changeset -> changeset
    end
  end
end
```

Add a lock action to your user context module:

```elixir
defmodule MyApp.Users do
  # ...
  alias MyApp.Users.User

  # ...

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
  # ...

  plug :load_user when action in [:delete]

  # ...

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(%{assigns: %{user: user}} = conn, _params) do
    case MyApp.Users.lock(user) do
      {:ok, _user} -> # User has been locked
      {:error, _changeset} -> # Something went wrong
    end
  end

  # ...

  defp load_user(%{params: %{"id" => user_id}} = conn, _opts) do
    config = Pow.Plug.fetch_config(conn)

    case Pow.Ecto.Context.get_by([id: user_id], config) do
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
    {:ok, conn} = Plug.clear_authenticated_user(conn)

    conn
    |> Controller.put_flash(:error, "Sorry, your account is locked.")
    |> Controller.redirect(to: Routes.pow_session_path(conn, :new))
  end
  defp maybe_halt(_any, conn), do: conn
end
```

Add `plug MyAppWeb.EnsureUserNotLockedPlug` to your endpoint or pipeline, and presto!
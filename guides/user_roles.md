# How to add user roles

Adding user roles is very simple, and you won't need an extension for this. This can be done in several ways, but we'll work with the most straight forward setup.

## Update your schema

Add a `role` column to your user schema. In our example, we'll set it so it can only have `user` and `admin` value, and defaults to `user`:

```elixir
defmodule MyApp.Users.User do
  # ...

  schema "users" do
    field :role, :string, default: "user"

    pow_user_fields()

    timestamp()
  end

  def changeset(user_or_changeset, attrs) do
    user_or_changeset
    |> pow_changeset(attrs)
    |> changeset_role(attrs)
  end

  def changeset_role(user_or_changeset, attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:role])
    |> Ecto.Changeset.validate_inclusion(:role, ~w(user admin))
  end

  # ...
end
```

## Add role plug

This is all the work you'll need to control access:

```elixir
defmodule MyAppWeb.EnsureRolePlug do
  @moduledoc """
  This plug ensures that a user has a particular role.

  ## Example

      plug MyAppWeb.EnsureRolePlug, [:user, :admin]

      plug MyAppWeb.EnsureRolePlug, :admin

      plug MyAppWeb.EnsureRolePlug, ~w(user admin)a
  """
  import Plug.Conn, only: [halt: 1]

  alias MyAppWeb.Router.Helpers, as: Routes
  alias Phoenix.Controller
  alias Plug.Conn
  alias Pow.Plug

  @doc false
  @spec init(any()) :: any()
  def init(config), do: config

  @doc false
  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, roles) do
    conn
    |> Plug.current_user()
    |> has_role?(roles)
    |> maybe_halt(conn)
  end

  defp has_role?(nil, _roles), do: false
  defp has_role?(user, roles) when is_list(roles), do: Enum.any?(roles, &has_role?(user, &1))
  defp has_role?(user, role) when is_atom(role), do: has_role?(user, Atom.to_string(role))
  defp has_role?(%{role: role}, role), do: true
  defp has_role?(_user, _role), do: false

  defp maybe_halt(true, conn), do: conn
  defp maybe_halt(_any, conn) do
    conn
    |> Controller.put_flash(:error, "Unauthorized access")
    |> Controller.redirect(to: Routes.page_path(conn, :index))
    |> halt()
  end
end
```

Now you can add `plug MyAppWeb.EnsureRolePlug, :admin` to your pipeline in `router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  # ...

  pipeline :admin do
    plug MyAppWeb.EnsureRolePlug, :admin
  end

  scope "/admin", MyAppWeb do
    pipe_through [:browser, :admin]

    # ...
  end

  # ...
end
```

Or you can add it to your controller(s):

```elixir
defmodule MyAppWeb.SomeController do
  use MyAppWeb, :controller

  # ...

  plug MyAppWeb.EnsureRolePlug, :admin

  # ...
end
```

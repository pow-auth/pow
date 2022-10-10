# How to add user roles

Adding user roles is very simple, and you won't need an extension for this. This can be done in several ways, but we'll work with the most straight forward setup.

## Update your schema

Add a `role` column to your user schema. In our example, we'll set the default role to `user` and add a `changeset_role/2` function that ensures the role can only be `user` or `admin`.

```elixir
# lib/my_app/users/user.ex
defmodule MyApp.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema

  schema "users" do
    field :role, :string, default: "user"

    pow_user_fields()

    timestamps()
  end

  @spec changeset_role(Ecto.Schema.t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset_role(user_or_changeset, attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:role])
    |> Ecto.Changeset.validate_inclusion(:role, ~w(user admin))
  end
end
```

To keep your app secure you shouldn't allow any direct calls to `changeset_role/2` with params provided by the user. Instead you should set up functions in your users context module to either create an admin user or update the role of an existing user:

```elixir
# lib/my_app/users.ex
defmodule MyApp.Users do
  alias MyApp.{Repo, Users.User}

  @type t :: %User{}

  @spec create_admin(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create_admin(params) do
    %User{}
    |> User.changeset(params)
    |> User.changeset_role(%{role: "admin"})
    |> Repo.insert()
  end

  @spec set_admin_role(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def set_admin_role(user) do
    user
    |> User.changeset_role(%{role: "admin"})
    |> Repo.update()
  end
end
```

Now you can safely call either `MyApp.Users.create_admin/1` or `MyApp.Users.set_admin_role/1` from your controllers.

## Add role plug

This is all the work you'll need to control access:

```elixir
# lib/my_app_web/ensure_role_plug.ex
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
  @spec call(Conn.t(), atom() | binary() | [atom()] | [binary()]) :: Conn.t()
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
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router

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
# lib/my_app_web/controllers/some_controller.ex
defmodule MyAppWeb.SomeController do
  use MyAppWeb, :controller

  # ...

  plug MyAppWeb.EnsureRolePlug, :admin

  # ...
end
```

## Using role permissions with layout

You may wish to render certain sections in your layout for certain roles. First let's add a helper function to the users context:

```elixir
# lib/my_app/users.ex
defmodule MyApp.Users do
  alias MyApp.{Repo, Users.User}

  # ...

  @spec is_admin?(t()) :: boolean()
  def is_admin?(%{role: "admin"}), do: true
  def is_admin?(_any), do: false
end
```

Now we can use that helper to conditionally render a section in our templates:

```elixir
<%= if MyApp.Users.is_admin?(@current_user) do %>
  <div>
    <p>You have admin access</p>
  </div>
<% end %>
```

## Test modules

```elixir
# test/my_app/users/user_test.exs
defmodule MyApp.Users.UserTest do
  use MyApp.DataCase

  alias MyApp.Users.User

  test "changeset/2 sets default role" do
    user =
      %User{}
      |> User.changeset(%{})
      |> Ecto.Changeset.apply_changes()

    assert user.role == "user"
  end

  test "changeset_role/2" do
    changeset = User.changeset_role(%User{}, %{role: "invalid"})
    assert changeset.errors[:role] == {"is invalid", [validation: :inclusion, enum: ["user", "admin"]]}

    changeset = User.changeset_role(%User{}, %{role: "admin"})
    refute changeset.errors[:role]
  end
end
```

```elixir
# test/my_app/users_test.exs
defmodule MyApp.UsersTest do
  use MyApp.DataCase

  alias MyApp.{Repo, Users, Users.User}

  @valid_params %{email: "test@example.com", password: "secret1234", password_confirmation: "secret1234"}

  test "create_admin/2" do
    assert {:ok, user} = Users.create_admin(@valid_params)
    assert user.role == "admin"
  end

  test "set_admin_role/1" do
    assert {:ok, user} = Repo.insert(User.changeset(%User{}, @valid_params))
    assert user.role == "user"

    assert {:ok, user} = Users.set_admin_role(user)
    assert user.role == "admin"
  end

  # Uncomment if you added this function to your users context
  # test "is_admin?/1" do
  #   refute Users.is_admin?(nil)
  #
  #   assert {:ok, user} = Repo.insert(User.changeset(%User{}, @valid_params))
  #   refute Users.is_admin?(user)
  #
  #   assert {:ok, admin} = Users.create_admin(%{@valid_params | email: "test2@example.com"})
  #   assert Users.is_admin?(admin)
  # end
end
```

```elixir
# test/my_app_web/ensure_role_plug_test.exs
defmodule MyAppWeb.EnsureRolePlugTest do
  use MyAppWeb.ConnCase

  alias MyAppWeb.EnsureRolePlug

  @opts ~w(admin)a
  @user %{id: 1, role: "user"}
  @admin %{id: 2, role: "admin"}

  setup do
    conn =
      build_conn()
      |> Plug.Conn.put_private(:plug_session, %{})
      |> Plug.Conn.put_private(:plug_session_fetch, :done)
      |> Pow.Plug.put_config(otp_app: :my_app)
      |> fetch_flash()

    {:ok, conn: conn}
  end

  test "call/2 with no user", %{conn: conn} do
    opts = EnsureRolePlug.init(@opts)
    conn = EnsureRolePlug.call(conn, opts)

    assert conn.halted
    assert redirected_to(conn) == Routes.page_path(conn, :index)
  end

  test "call/2 with non-admin user", %{conn: conn} do
    opts = EnsureRolePlug.init(@opts)
    conn =
      conn
      |> Pow.Plug.assign_current_user(@user, otp_app: :my_app)
      |> EnsureRolePlug.call(opts)

    assert conn.halted
    assert redirected_to(conn) == Routes.page_path(conn, :index)
  end

  test "call/2 with non-admin user and multiple roles", %{conn: conn} do
    opts = EnsureRolePlug.init(~w(user admin)a)
    conn =
      conn
      |> Pow.Plug.assign_current_user(@user, otp_app: :my_app)
      |> EnsureRolePlug.call(opts)

    refute conn.halted
  end

  test "call/2 with admin user", %{conn: conn} do
    opts = EnsureRolePlug.init(@opts)
    conn =
      conn
      |> Pow.Plug.assign_current_user(@admin, otp_app: :my_app)
      |> EnsureRolePlug.call(opts)

    refute conn.halted
  end
end
```

# How to lock users

Locking users is trivial, and you won't need an extension for this. It can be done in several ways, but we'll work with the most straight forward setup.

## Update your schema

Add a `locked_at` column to your user schema, and a `lock_changeset/1` function to lock the account:

```elixir
# lib/my_app/users/user.ex
defmodule MyApp.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  
  alias Ecto.{Changeset, Schema}

  schema "users" do
    field :locked_at, :utc_datetime

    pow_user_fields()

    timestamps()
  end

  @spec lock_changeset(Schema.t() | Changeset.t()) :: Changeset.t()
  def lock_changeset(user_or_changeset) do
    changeset = Changeset.change(user_or_changeset)
    locked_at = DateTime.truncate(DateTime.utc_now(), :second)

    case Changeset.get_field(changeset, :locked_at) do
      nil  -> Changeset.change(changeset, locked_at: locked_at)
      _any -> Changeset.add_error(changeset, :locked_at, "already set")
    end
  end
end
```

Add a lock action to your user context module:

```elixir
# lib/my_app/users.ex
defmodule MyApp.Users do
  alias MyApp.{Repo, Users.User}

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
# lib/my_app_web/controllers/admin/user_controller.ex
defmodule MyAppWeb.Admin.UserController do
  use MyAppWeb, :controller

  alias Plug.Conn
  alias Pow.{Plug, Operations}
  alias MyApp.Users

  plug :load_user when action in [:lock]

  # ...

  @spec lock(Conn.t(), map()) :: Conn.t()
  def lock(%{assigns: %{user: user}} = conn, _params) do
    case Users.lock(user) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User has been locked.")
        |> redirect(to: "/")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "User couldn't be locked.")
        |> redirect(to: "/")
    end
  end

  defp load_user(%{params: %{"id" => user_id}} = conn, _opts) do
    config = Plug.fetch_config(conn)

    case Operations.get_by([id: user_id], config) do
      nil ->
        conn
        |> put_flash(:error, "User doesn't exist")
        |> redirect(to: "/")

      user ->
        assign(conn, :user, user)
    end
  end
end
```

Remember to add this route to your `router.ex` file:

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router

  # ...

  scope "/admin", MyAppWeb.Admin, as: :admin do
    pipe_through :browser
    # Usually you would lock this area with a plug:
    # pipe_through [:browser, :require_admin_user]

    post "/users/:id/lock", UserController, :lock
  end

  # ...
end
```

## Prevent sign in for locked users

This is all you need to ensure locked users can't sign in:

```elixir
# lib/my_app_web/ensure_user_not_locked_plug.ex
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
# lib/my_app_web/controllers/reset_password_controller.ex
defmodule MyAppWeb.ResetPasswordController do
  use MyAppWeb, :controller

  alias PowResetPassword.{Phoenix.ResetPasswordController, Plug, Store.ResetTokenCache}

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
    config = Pow.Plug.fetch_config(conn)

    case Pow.Plug.verify_token(conn, Atom.to_string(PowResetPassword.Plug), token, config) do
      {:ok, token} ->
        backend = Pow.Config.get(config, :cache_store_backend, Pow.Store.Backend.EtsCache)

        ResetTokenCache.delete([backend: backend], token)

      :error ->
        :ok
    end
  end
end
```

To make the code simpler for us we're leveraging the functions from `PowResetPassword.Phoenix.ResetPasswordController` here.

Now all we got to do is to catch the route before the `pow_extension_routes/0` call:

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router
  use Pow.Extension.Phoenix.Router,
    extensions: [PowResetPassword]

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

## Test modules

```elixir
# test/my_app/users_test.exs
defmodule MyApp.UsersTest do
  use MyApp.DataCase

  alias MyApp.{Repo, Users, Users.User}

  @valid_params %{email: "test@example.com", password: "secret1234", password_confirmation: "secret1234"}

  test "lock/2" do
    assert {:ok, user} = Repo.insert(User.changeset(%User{}, @valid_params))
    refute user.locked_at

    assert {:ok, user} = Users.lock(user)
    assert user.locked_at

    assert {:error, changeset} = Users.lock(user)
    assert changeset.errors[:locked_at] == {"already set", []}
  end
end
```

```elixir
# test/my_app_web/controllers/admin/user_controller_test.exs
defmodule MyAppWeb.Admin.UserControllerTest do
  use MyAppWeb.ConnCase

  alias MyApp.{Users, Users.User, Repo}

  describe "lock/2" do
    test "locks user", %{conn: conn} do
      user = user_fixture()

      conn = post(conn, Routes.admin_user_path(conn, :lock, user.id))

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "User has been locked."
      assert redirected_to(conn) == "/"
    end

    test "with already locked user", %{conn: conn} do
      {:ok, user} = Users.lock(user_fixture())

      conn = post(conn, Routes.admin_user_path(conn, :lock, user.id))

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "User couldn't be locked."
      assert redirected_to(conn) == "/"
    end
  end

  defp user_fixture() do
    %User{}
    |> User.changeset(%{email: "test@example.com", password: "secret1234", password_confirmation: "secret1234"})
    |> Repo.insert!()
  end
end
```

```elixir
# test/my_app_web/ensure_user_not_locked_plug_test.exs
defmodule MyAppWeb.EnsureUserNotLockedPlugTest do
  use MyAppWeb.ConnCase

  alias MyApp.Users.User
  alias MyAppWeb.EnsureUserNotLockedPlug

  @pow_config [otp_app: :my_app]
  @user %User{id: 1, locked_at: nil}
  @locked_user %User{id: 2, locked_at: DateTime.utc_now()}
  @plug_opts []

  setup do
    {:ok, conn: init_conn()}
  end

  test "call/2 with no user", %{conn: conn} do
    opts = EnsureUserNotLockedPlug.init(@plug_opts)
    conn = EnsureUserNotLockedPlug.call(conn, opts)

    refute conn.halted
  end

  test "call/2 with user", %{conn: conn} do
    opts = EnsureUserNotLockedPlug.init(@plug_opts)
    conn =
      conn
      |> Pow.Plug.assign_current_user(@user, @pow_config)
      |> EnsureUserNotLockedPlug.call(opts)

    refute conn.halted
  end

  test "call/2 with locked user", %{conn: conn} do
    opts = EnsureUserNotLockedPlug.init(@plug_opts)
    conn =
      conn
      |> Pow.Plug.assign_current_user(@locked_user, @pow_config)
      |> EnsureUserNotLockedPlug.call(opts)

    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Sorry, your account is locked."
    assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
  end

  defp init_conn() do
    pow_config = Keyword.put(@pow_config, :plug, Pow.Plug.Session)

    :get
    |> Plug.Test.conn("/")
    |> Plug.Test.init_test_session(%{})
    |> Pow.Plug.put_config(pow_config)
    |> fetch_flash()
  end
end
```

```elixir
# test/my_app_web/controllers/reset_password_controller_test.exs
defmodule MyAppWeb.ResetPasswordControllerTest do
  use MyAppWeb.ConnCase

  alias MyApp.{Users, Users.User, Repo}
  alias PowResetPassword.Store.ResetTokenCache

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com"}}

    test "with user", %{conn: conn} do
      user = user_fixture()

      conn = post(conn, Routes.reset_password_path(conn, :create, @valid_params))

      assert Phoenix.Flash.get(conn.assigns.flash, :info)
      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)

      assert count_reset_password_tokens_for_user(conn, user) == 1
    end

    test "with locked user", %{conn: conn} do
      {:ok, user} = Users.lock(user_fixture())

      conn = post(conn, Routes.reset_password_path(conn, :create, @valid_params))

      assert Phoenix.Flash.get(conn.assigns.flash, :info)
      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)

      assert count_reset_password_tokens_for_user(conn, user) == 0
    end
  end

  defp user_fixture() do
    %User{}
    |> User.changeset(%{email: "test@example.com", password: "secret1234", password_confirmation: "secret1234"})
    |> Repo.insert!()
  end

  defp count_reset_password_tokens_for_user(conn, user) do
    backend =
      conn
      |> Pow.Plug.fetch_config()
      |> Pow.Config.get(:cache_store_backend, Pow.Store.Backend.EtsCache)

    [backend: backend]
    |> ResetTokenCache.all([:_])
    |> Enum.filter(fn {_key, %{id: id}} -> id == user.id end)
    |> length()
  end
end
```
# How to sync changes to the user made by actions outside of Pow

Let's say you added a `plan` column on your `users` table and have the following controller which updates the plan your user is subscribed to:

```elixir
def update_plan(conn, %{"plan" => plan}) do
  case Users.update_plan(conn.assigns.current_user, plan) do
    {:ok, user} ->
      conn
      |> put_flash(:info, "Plan updated successfully.")
      |> redirect(to: Routes.profile_path(conn, :show))

    {:error, %Ecto.Changeset{} = changeset} ->
      render(conn, "plan.html", changeset: changeset)
  end
end
```

The change in the `plan` will not be reflected in `conn.assigns.user` because it is cached. In order to fix this you can notify the `EnsureUserInSync` plug of the change by setting the `:sync_user` session property to true:

```elixir
def update_plan(conn, %{"plan" => plan}) do
  case Users.update_plan(conn.assigns.current_user, plan) do
    {:ok, user} ->
      conn
      |> put_session(:sync_user, true)
      |> put_flash(:info, "Plan updated successfully.")
      |> redirect(to: Routes.profile_path(conn, :show))

    {:error, %Ecto.Changeset{} = changeset} ->
      render(conn, "plan.html", changeset: changeset)
  end
end
```

## Add ensure user in sync plug

```elixir
defmodule MyAppWeb.EnsureUserInSync do
  @moduledoc """
  This plug ensures that the current user in the session is in sync with the database.

  ## Example

      plug MyAppWeb.EnsureUserInSync
  """

  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(config), do: config

  @doc false
  @spec call(Conn.t(), list) :: Conn.t()
  def call(conn, config) do
    conn
    |> Conn.get_session(:sync_user)
    |> maybe_sync_user(conn)
  end

  defp maybe_sync_user(true, %{assigns: %{current_user: %{id: user_id}}} = conn) do
    config = Pow.Plug.fetch_config(conn)
    user   = Pow.Ecto.Context.get_by([id: user_id], config)

    conn
    |> Conn.delete_session(:sync_user)
    |> Pow.Plug.Session.do_create(user, config)
  end
  defp maybe_sync_user(_, conn), do: conn
end
```

Add `plug MyAppWeb.EnsureUserInSync` to your pipeline under `lib/myapp_web/endpoint.ex`:

```elixir
plug Pow.Plug.Session, otp_app: :my_app
plug MyAppWeb.EnsureUserInSync
```
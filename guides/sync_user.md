# Update cached user credentials

You may want to update the cached user credentials when an action outside of Pow has updated the user. It's very important to understand that the cached user credentials that Pow fetches in `Pow.Plug.current_user/2` is always to be considered out of date since it's a cached object.

In the following examples we'll imagine that you've added a `plan` column on your `users` table. We may want to use that `plan` to give them access to a certain controller actions. In this case, it's paramount that you load the user from the database.

## Reload the user

```elixir
defmodule MyAppWeb.ProPlanController do
  # ...
  plug :reload_user

  # ...

  defp reload_user(conn, _opts) do
    config        = Pow.Plug.fetch_config(conn)
    user          = Pow.Plug.current_user(conn, config)
    reloaded_user = MyApp.Repo.get!(MyApp.User, user.id)

    Pow.Plug.assign_current_user(conn, reloaded_user, config)
  end
end
```

This should always be done for any authorization actions, or any other actions that requires the actual value to be known.

## Update user in credentials cache

Let's say that you want to show the user `plan` on most pages. In this case we can safely rely on the cached credentials since we don't need to know the actual value in the database. The worst case is that a different plan may be shown if you haven't ensured that all plan update actions uses the below method.

We can use `do_create/3` defined in the `Pow.Plug.Base` macro to update the cached credentials.

First we'll make a helper and import it to our controllers:

```elixir
defmodule MyAppWeb.PowHelper do
  @spec sync_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def sync_user(conn, user) do
    config = Pow.Plug.fetch_config(conn)
    plug   = Pow.Plug.get_plug(config)

    plug.do_create(conn, user, config)
  end
end
```

```elixir
defmodule MyAppWeb do
  # ...

  def controller do
    quote do
      use Phoenix.Controller, namespace: MyAppWeb

      # ...
      import MyAppWeb.PowHelper
    end
  end

  # ...
end
```

Now we can call `sync_user/2` in any controller actions. It could maybe be the update action for your plan controller:

```elixir
defmodule MyAppWeb.PlanController do
  # ...

  def update(conn, %{"plan" => plan}) do
    conn
    |> Plug.current_user()
    |> MyApp.Users.update_plan(plan)
    |> case do
      {:ok, user} ->
        conn
        |> sync_user(user) # Update the user in the credentials cache
        |> put_flash(:info, "Plan updated successfully.")
        |> redirect(to: Routes.profile_path(conn, :show))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "plan.html", changeset: changeset)
    end
  end

  # ...
end
```

As you can see in the above, the cached user credentials will be updated after a successful update of plan for the user. Now any subsequent pages being rendered, you'll have access to the updated `plan` value in the current user assign.

Another thing to note is that if you're using `Pow.Plug.Session`, then the session id will also be regenerated this way. This is ideal for authorization level change (what the above `plan` change action may be).

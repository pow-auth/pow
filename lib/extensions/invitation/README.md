# PowInvitation

This extension will set up a basic invitation system where users can invite other users to join. If `:email` field exists on the user struct an e-mail is sent out with an invitation link. Otherwise a page with the invitation link is shown.

Invited users are persisted in the database without a password. Only the user id will be validated when the user is invited, but `changeset/2` on your user schema will be used for when the user accepts the invitation.

To prevent user enumeration, the invited user will, to the inviter, appear as succesfully invited even if the user couldn't be created due to unique constraint error on `:email`. No e-mail will be sent out. If `pow_prevent_user_enumeration: false` is set in `conn.private` the form with error will be shown instead.

An invited user can change their e-mail when accepting the invitation. To prevent user enumeration `PowEmailConfirmation` extension can be enabled.

## Installation

Follow the instructions for extensions in [README.md](../../../README.md#add-extensions-support), and set `PowInvitation` in the `:extensions` list.

## Configuration

There are numerous ways you can modify the invitation flow. Here's a few common setups to get your started.

### Parent organization or team

If your users belongs to a parent organization or team, you can set up the `invite_changeset/3` to carry over the id for invitations:

```elixir
defmodule MyApp.Users.User do
  # ...

  def invite_changeset(user_or_changeset, invited_by, attrs) do
    user_or_changeset
    |> pow_invite_changeset(invited_by, attrs)
    |> changeset_organization(invited_by)
  end

  defp changeset_organization(changeset, invited_by) do
    Ecto.Changeset.change(changeset, organization_id: invited_by.organization_id)
  end
end
```

### Limit invitation based on role

If you have different roles (e.g. [admin and user](../../../guides/user_roles.md)), you can limit the type of user who can invite others by using a plug and override the routes in your `router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  # ...

  pipeline :admin_role do
    plug MyAppWeb.EnsureRolePlug, :admin
  end

  scope "/", PowInvitation.Phoenix, as: "pow_invitation" do
    pipe_through [:browser, :protected, :admin_role]

    resources "/invitations", InvitationController, only: [:new, :create, :show]
  end

  # ... you would want `pow_extension_routes/0` with the default routes to be after this
end
```

The routes will override the default ones in `pow_extension_routes/0`.

### Limit registration

If you wish to restrict signup to only invites, you can modify `router.ex` to exclude registration by using `pow_session_routes/0` in place of `pow_routes/0`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  # ...

  scope "/" do
    pipe_through :browser

    pow_session_routes()
    pow_extension_routes()
  end

  # ...
end
```

You need to  use custom template for the session controller, since by default it'll still have the link to registration. Read more in the [Disable registration guide](../../../guides/disable_registration.md).

### Expire invited users

Invited users will have a token set in the `:invitation_token` field and `:invitation_accepted_at` field set to nil. If you want to expire the invitation link you can run a background task to delete these users a certain time after `:inserted_at`.

## Note on PowEmailConfirmation

[PowEmailConfirmation](../email_confirmation/README.md) will only require email confirmation if the invited user changes their email when accepting their invitation.

defmodule PowInvitation.Test.RepoMock do
  @moduledoc false

  alias PowInvitation.Test.Users.User

  @user %User{id: 1, email: "test@example.com"}

  def insert(%{changes: %{email: "taken@example.com"}, valid?: true} = changeset, _opts) do
    changeset = Ecto.Changeset.add_error(changeset, :email, "has already been taken", constraint: :unique, constraint_name: "users_email_index")

    {:error, %{changeset | action: :insert}}
  end
  def insert(%{valid?: true} = changeset, _opts) do
    user = %{Ecto.Changeset.apply_changes(changeset) | id: 1}

    # We store the user in the process because the user is force reloaded with `get!/2`
    Process.put({:user, 1}, user)

    {:ok, user}
  end
  def insert(%{changes: %{email: "no_email"}} = changeset, opts) do
    changeset
    |> Map.put(:valid?, true)
    |> Ecto.Changeset.put_change(:email, nil)
    |> Ecto.Changeset.put_change(:invitation_token, "valid")
    |> insert(opts)
  end
  def insert(%{valid?: false} = changeset, _opts), do: {:error, %{changeset | action: :insert}}

  def get_by(User, [id: 1], _opts), do: Process.get({:user, 1})
  def get_by(User, [invitation_token: "valid"], _opts), do: %{@user | invitation_token: "valid"}
  def get_by(User, [invitation_token: "valid_but_accepted"], _opts), do: %{@user | invitation_accepted_at: :now}
  def get_by(User, [invitation_token: "invalid"], _opts), do: nil

  def update(%{changes: %{email: "taken@example.com"}, valid?: true} = changeset, _opts) do
    changeset = Ecto.Changeset.add_error(changeset, :email, "has already been taken", constraint: :unique, constraint_name: "users_email_index")

    {:error, %{changeset | action: :update}}
  end
  def update(%{valid?: true} = changeset, _opts) do
    user = Ecto.Changeset.apply_changes(changeset)

    # We store the user in the process because the user is force reloaded with `get!/2`
    Process.put({:user, user.id}, user)

    {:ok, user}
  end
  def update(%{valid?: false} = changeset, _opts), do: {:error, %{changeset | action: :update}}
end

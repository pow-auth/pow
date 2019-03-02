defmodule PowInvitation.Test.RepoMock do
  @moduledoc false

  alias PowInvitation.Test.Users.User

  @user %User{id: 1, email: "test@example.com"}

  def insert(%{valid?: true} = changeset) do
    user = %{Ecto.Changeset.apply_changes(changeset) | id: 1}

    # We store the user in the process because the user is force reloaded with `get!/2`
    Process.put({:user, 1}, user)

    {:ok, user}
  end
  def insert(%{changes: %{email: "no_email"}} = changeset) do
    changeset
    |> Map.put(:valid?, true)
    |> Ecto.Changeset.put_change(:email, nil)
    |> Ecto.Changeset.put_change(:invitation_token, "valid")
    |> insert()
  end
  def insert(%{valid?: false} = changeset), do: {:error, %{changeset | action: :insert}}

  def get!(User, 1), do: Process.get({:user, 1})

  def get_by(User, [invitation_token: "valid"]), do: %{@user | invitation_token: "valid"}
  def get_by(User, [invitation_token: "valid_but_accepted"]), do: %{@user | invitation_accepted_at: :now}
  def get_by(User, [invitation_token: "invalid"]), do: nil

  def update(%{valid?: true} = changeset), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
  def update(%{valid?: false} = changeset), do: {:error, %{changeset | action: :update}}
end

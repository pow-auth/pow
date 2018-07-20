defmodule PowEmailConfirmation.Test.RepoMock do
  alias PowEmailConfirmation.Test.Users.User

  def get_by(_mod, [email_confirmation_token: "valid"]), do: %User{id: 1}
  def get_by(_mod, _test), do: nil

  def update(%{valid?: true} = changeset), do: {:ok, Ecto.Changeset.apply_changes(changeset)}

  def insert(%{valid?: true} = changeset) do
    token = Ecto.Changeset.get_field(changeset, :email_confirmation_token)
    email = Ecto.Changeset.get_field(changeset, :email)

    {:ok, %User{id: 1, email_confirmation_token: token, email: email}}
  end
end

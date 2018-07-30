defmodule PowEmailConfirmation.Test.RepoMock do
  @moduledoc false
  alias PowEmailConfirmation.Test.Users.User

  @user %User{id: 1}

  def get_by(User, [email_confirmation_token: "valid"]), do: @user
  def get_by(User, [email_confirmation_token: "invalid"]), do: nil

  def update(%{valid?: true} = changeset) do
    user = Ecto.Changeset.apply_changes(changeset)

    Process.put({:user, user.id}, user)

    {:ok, user}
  end

  def insert(%{valid?: true} = changeset) do
    token = Ecto.Changeset.get_field(changeset, :email_confirmation_token)
    email = Ecto.Changeset.get_field(changeset, :email)
    user  = %{@user | email_confirmation_token: token, email: email}

    Process.put({:user, user.id}, user)

    {:ok, user}
  end

  def get!(User, 1), do: Process.get({:user, 1})
end

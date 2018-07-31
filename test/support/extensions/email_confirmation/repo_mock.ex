defmodule PowEmailConfirmation.Test.RepoMock do
  @moduledoc false
  alias PowEmailConfirmation.Test.Users.User

  @user %User{id: 1, email: "test@example.com", email_confirmation_token: "valid", password_hash: Comeonin.Pbkdf2.hashpwsalt("secret1234")}

  def get_by(User, [email: "test@example.com"]) do
    get_by(User, [email_confirmation_token: "valid"])
  end
  def get_by(User, [email: "confirmed@example.com"]) do
    get_by(User, [email_confirmation_token: "valid_confirmed"])
  end
  def get_by(User, [email_confirmation_token: "valid"]),
    do: Ecto.put_meta(@user, state: :loaded)
  def get_by(User, [email_confirmation_token: "invalid"]),
    do: nil
  def get_by(User, [email_confirmation_token: "valid_confirmed"]) do
    %{get_by(User, [email_confirmation_token: "valid"]) | email_confirmed_at: DateTime.utc_now()}
  end
  def get_by(User, [email_confirmation_token: "valid_unconfirmed_email"]) do
    %{get_by(User, [email_confirmation_token: "valid_confirmed"]) | unconfirmed_email: "new@example.com"}
  end

  def update(%{changes: %{email: "taken@example.com"}} = changeset) do
    changeset = Ecto.Changeset.add_error(changeset, :email, "has already been taken")

    {:error, changeset}
  end
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

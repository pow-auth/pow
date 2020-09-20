defmodule PowResetPassword.Test.RepoMock do
  @moduledoc false
  alias PowResetPassword.Test.Users.User

  @user %User{id: 1}

  def get_by(User, [id: 1], _opts), do: Process.get({:user, 1})
  def get_by(User, [email: "test@example.com"], _opts), do: @user
  def get_by(User, [email: "invalid@example.com"], _opts), do: nil

  def update(%{valid?: true} = changeset, _opts) do
    user = Ecto.Changeset.apply_changes(changeset)

    # We store the user in the process because the user is force reloaded with `get!/2`
    Process.put({:user, user.id}, user)

    {:ok, user}
  end
  def update(%{valid?: false} = changeset, _opts), do: {:error, %{changeset | action: :update}}
end

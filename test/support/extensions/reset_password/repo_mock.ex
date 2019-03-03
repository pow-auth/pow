defmodule PowResetPassword.Test.RepoMock do
  @moduledoc false
  alias PowResetPassword.Test.Users.User

  @user %User{id: 1}

  def get_by(User, [email: "test@example.com"]), do: @user
  def get_by(User, [email: "invalid@example.com"]), do: nil

  def update(%{valid?: true} = changeset) do
    user = Ecto.Changeset.apply_changes(changeset)

    # We store the user in the process because the user is force reloaded with `get!/2`
    Process.put({:user, 1}, user)

    {:ok, user}
  end
  def update(%{valid?: false} = changeset), do: {:error, %{changeset | action: :update}}

  def get!(User, 1), do: Process.get({:user, 1})
  def get!(User, :missing), do: nil
end

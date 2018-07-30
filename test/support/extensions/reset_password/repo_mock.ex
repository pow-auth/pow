defmodule PowResetPassword.Test.RepoMock do
  @moduledoc false
  alias PowResetPassword.Test.Users.User

  @user %User{id: 1}

  def get_by(User, [email: "test@example.com"]), do: @user
  def get_by(User, [email: "invalid@example.com"]), do: nil

  def update(%{valid?: true}), do: {:ok, @user}
  def update(%{valid?: false} = changeset), do: {:error, %{changeset | action: :update}}

  def get!(User, 1), do: @user
end

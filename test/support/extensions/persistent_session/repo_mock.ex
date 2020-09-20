defmodule PowPersistentSession.Test.RepoMock do
  @moduledoc false
  alias Pow.Ecto.Schema.Password
  alias PowPersistentSession.Test.Users.User

  @user %User{id: 1, email: "test@example.com", password_hash: Password.pbkdf2_hash("secret1234")}

  def get_by(User, [id: 1], _opts), do: @user
  def get_by(User, [id: -1], _opts), do: nil
  def get_by(User, [email: "test@example.com"], _opts), do: @user
end

defmodule PowRateLimiter.Test.RepoMock do
  @moduledoc false
  alias Pow.Ecto.Schema.Password
  alias PowRateLimiter.Test.Users.User

  defp user() do
    Ecto.put_meta(%User{
      id: 1,
      email: "test@example.com",
      password_hash: Password.pbkdf2_hash("secret1234")
    }, state: :loaded)
  end

  def get_by(User, [email: "test@example.com"], _opts), do: user()
end

defmodule PowInvitation.Ecto.ContextTest do
  use Pow.Test.Ecto.TestCase
  doctest PowInvitation.Ecto.Context

  alias PowInvitation.Ecto.Context
  alias PowInvitation.Test.{RepoMock, Users.User}

  @config [repo: RepoMock, user: User]

  defmodule CustomUsers do
    def get_by([invitation_token: :test]), do: %User{email: :ok}
  end

  describe "get_by_invitation_token/2" do
    test "gets when :invitation_accepted_at is nil" do
      assert Context.get_by_invitation_token("valid", @config)
    end

    test "nil when :invitation_accepted_at is not nil" do
      refute Context.get_by_invitation_token("valid_but_accepted", @config)
    end

    test "with `:users_context`" do
      assert %User{email: :ok} = Context.get_by_invitation_token(:test, @config ++ [users_context: CustomUsers])
    end
  end
end

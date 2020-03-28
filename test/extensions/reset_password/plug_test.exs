defmodule PowResetPassword.PlugTest do
  use ExUnit.Case
  doctest PowResetPassword.Plug

  alias Plug.Conn
  alias Pow.Plug, as: PowPlug
  alias PowResetPassword.{Plug, Test, Test.Users.User}
  alias ExUnit.CaptureIO

  describe "update_user_password/2" do
    @valid_params %{"password" => "secret1234", "password_confirmation" => "secret1234"}

    test "without decoded token warns" do
      assert CaptureIO.capture_io(:stderr, fn ->
        assert {:ok, _user, _conn} =
          %Conn{}
          |> PowPlug.put_config(Test.pow_config())
          |> Conn.assign(:reset_password_user, %User{id: 1})
          |> Plug.update_user_password(@valid_params)
      end) =~ "no `:pow_reset_password_decoded_token` key found in `conn.private`, please call `PowResetPassword.Plug.load_user_by_token/2` first"
    end
  end
end

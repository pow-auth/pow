defmodule PowRateLimiter.Phoenix.ControllerCallbacksTest do
  use PowRateLimiter.TestWeb.Phoenix.ConnCase

  alias PowRateLimiter.{Engine.Ets, Plug}
  alias PowRateLimiter.Test.Users.User

  setup do
    start_supervised!({Ets, []})

    :ok
  end

  @valid_params %{"email" => "test@example.com", "password" => "secret1234"}
  @invalid_params %{"email" => "test@example.com", "password" => "invalid"}
  @ets_key "rate_count:#{Base.url_encode64("test@example.com", padding: false)}"

  describe "Pow.Phoenix.SessionController.create/2" do
    test "when fails increase failed login attempts", %{conn: conn} do
      conn = post conn, Routes.pow_session_path(conn, :create, %{"user" => @invalid_params})

      assert html = html_response(conn, 200)
      assert get_flash(conn, :error) == "The provided login details did not work. Please verify your credentials, and try again."

      assert get_rate_count() == 1
    end

    test "when succeds clears failed login attempts", %{conn: conn} do
      increase_rate(conn)
      assert get_rate_count() == 1

      conn = post conn, Routes.pow_session_path(conn, :create, %{"user" => @valid_params})

      assert redirected_to(conn) == "/after_signed_in"
      assert Pow.Plug.current_user(conn)

      refute get_rate_count()
    end

    test "halts when too many consecutive failed login attempts", %{conn: conn} do
      for _n <- 1..100, do: increase_rate(conn)
      assert get_rate_count() == 100

      conn = post conn, Routes.pow_session_path(conn, :create, %{"user" => @valid_params})

      assert redirected_to(conn) == "/session/new"
      assert get_flash(conn, :error) == "You have attempted sign in too many times. Please wait a while before you try again."
    end
  end

  defp increase_rate(conn) do
    Plug.increase_rate_check(%{conn | params: %{"user" => @valid_params}, private: %{pow_config: [user: User]}})
  end

  defp get_rate_count() do
    case :ets.lookup(Ets, @ets_key) do
      [{_, count, _, _}] -> count
      []                 -> nil
    end
  end
end

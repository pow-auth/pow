defmodule Pow.ConfigTest do
  use ExUnit.Case
  doctest Pow.Config

  alias Pow.Config

  test "get/1" do
    assert Config.get([], :key, 0) == 0

    Application.put_env(:pow, :key, 1)
    assert Config.get([], :key, 0) == 1

    Application.put_env(:test, :pow, [key: 2])
    assert Config.get([otp_app: :test], :key, 0) == 2

    assert Config.get([otp_app: :test, key: 3], :key, 0) == 3
    assert Config.get([key: 3], :key, 0) == 3
  end
end

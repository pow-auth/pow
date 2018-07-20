defmodule Pow.ConfigTest do
  use ExUnit.Case
  doctest Pow.Config

  alias Pow.Config

  test "get/1" do
    assert Config.get([], :key, 0) == 0

    Application.put_env(:pow, Pow, [key: 1])
    assert Config.get([], :key, 0) == 1

    assert Config.get([key: 2], :key, 0) == 2
  end
end

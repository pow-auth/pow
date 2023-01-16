defmodule Pow.Ecto.Schema.Password.Pbkdf2Test do
  use ExUnit.Case
  import Bitwise

  alias Pow.Ecto.Schema.Password.Pbkdf2

  test "compare/2" do
    assert Pbkdf2.compare(<<>>, <<>>)
    assert Pbkdf2.compare(<<0>>, <<0>>)

    refute Pbkdf2.compare(<<>>, <<1>>)
    refute Pbkdf2.compare(<<1>>, <<>>)
    refute Pbkdf2.compare(<<0>>, <<1>>)
  end

  describe "generate/5" do
    @secret "secret"
    @salt "salt"
    @iterations 64
    @length 20
    @digest :sha512

    @max_length bsl(1, 32) - 1

    test "when length longer than max length" do
      assert_raise ArgumentError, ~r/length must be less than or equal/, fn ->
        Pbkdf2.generate(@secret, @salt, @iterations, @max_length + 1, @digest)
      end
    end

    test "when iterations is invalid" do
      for i <- [32.0, -1, nil, "many", :lots] do
        assert_raise ArgumentError, "iterations must be an integer >= 1", fn ->
          Pbkdf2.generate(@secret, @salt, i, @length, @digest)
        end
      end
    end

    test "generates hash" do
      key = Pbkdf2.generate(@secret, @salt, @iterations, @length, @digest)
      assert byte_size(key) == @length
      assert key == <<168, 236, 50, 221, 154, 138, 163, 60, 82, 206, 193, 197, 48, 48, 74, 247, 200, 9, 195, 135>>
    end
  end
end

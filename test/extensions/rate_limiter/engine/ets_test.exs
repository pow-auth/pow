defmodule PowRateLimiter.Engine.EtsTest do
  use ExUnit.Case
  doctest PowRateLimiter.Engine.Ets

  alias Pow.Config
  alias PowRateLimiter.Engine.Ets
  alias Plug.Conn

  @config [namespace: "namespace"]
  @conn %Conn{}
  @fingerprint "a"

  test "can increases, get and clear rates" do
    start_supervised!({Ets, @config})

    different_namespace = [namespace: "namespace2"]
    different_fingerprint = "b"

    for _n <- 1..98 do
      assert {:allow, _} = Ets.increase_rate_check(@config, @conn, @fingerprint)
      assert {:allow, _} = Ets.increase_rate_check(different_namespace, @conn, @fingerprint)
      assert {:allow, _} = Ets.increase_rate_check(@config, @conn, different_fingerprint)
    end

    assert {:allow, _} = Ets.increase_rate_check(@config, @conn, @fingerprint)
    assert {:allow, _} = Ets.increase_rate_check(different_namespace, @conn, @fingerprint)

    assert {:allow, _} = Ets.increase_rate_check(@config, @conn, @fingerprint)

    assert {:deny, _}  = Ets.increase_rate_check(@config, @conn, @fingerprint)
    assert {:allow, _} = Ets.increase_rate_check(different_namespace, @conn, @fingerprint)
    assert {:allow, _} = Ets.increase_rate_check(@config, @conn, different_fingerprint)

    assert {:deny, _}  = Ets.increase_rate_check(@config, @conn, @fingerprint)
    assert {:deny, _}  = Ets.increase_rate_check(different_namespace, @conn, @fingerprint)
    assert {:allow, _} = Ets.increase_rate_check(@config, @conn, different_fingerprint)

    assert {:deny, _} = Ets.increase_rate_check(@config, @conn, @fingerprint)
    assert {:deny, _} = Ets.increase_rate_check(different_namespace, @conn, @fingerprint)
    assert {:deny, _} = Ets.increase_rate_check(@config, @conn, different_fingerprint)

    assert Ets.clear_rate(@config, @conn, @fingerprint) == :ok

    assert {:allow, _} = Ets.increase_rate_check(@config, @conn, @fingerprint)
    assert {:deny, _}  = Ets.increase_rate_check(different_namespace, @conn, @fingerprint)
    assert {:deny, _}  = Ets.increase_rate_check(@config, @conn, different_fingerprint)

    assert Ets.clear_rate(different_namespace, @conn, @fingerprint) == :ok

    assert {:allow, _} = Ets.increase_rate_check(@config, @conn, @fingerprint)
    assert {:allow, _} = Ets.increase_rate_check(different_namespace, @conn, @fingerprint)
    assert {:deny, _}  = Ets.increase_rate_check(@config, @conn, different_fingerprint)

    assert Ets.clear_rate(@config, @conn, different_fingerprint) == :ok

    assert {:allow, _} = Ets.increase_rate_check(@config, @conn, @fingerprint)
    assert {:allow, _} = Ets.increase_rate_check(different_namespace, @conn, @fingerprint)
    assert {:allow, _} = Ets.increase_rate_check(@config, @conn, different_fingerprint)
  end

  test "can change rate limit" do
    config = Keyword.put(@config, :limit, 2)

    start_supervised!({Ets, config})

    for _n <- 1..2, do: assert {:allow, _} = Ets.increase_rate_check(config, @conn, @fingerprint)

    assert {:deny, _} = Ets.increase_rate_check(config, @conn, @fingerprint)
  end

  test "rate limit expires" do
    ttl    = 200
    config = Config.merge(@config, limit: 1, ttl: ttl, sweep_interval: 100)

    start_supervised!({Ets, config})

    assert {:allow, _} = Ets.increase_rate_check(config, @conn, @fingerprint)
    assert {:deny, _}  = Ets.increase_rate_check(config, @conn, @fingerprint)

    :timer.sleep(ttl + 100)

    assert {:allow, _} = Ets.increase_rate_check(config, @conn, @fingerprint)
  end
end

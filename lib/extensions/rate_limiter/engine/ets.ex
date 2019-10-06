defmodule PowRateLimiter.Engine.Ets do
  @moduledoc """
  An ETS based rate limiter.

  ## Usage

  To start the GenServer, add it to your application `start/2` method:

      defmodule MyAppWeb.Application do
        use Application

        def start(_type, _args) do
          children = [
            MyApp.Repo,
            MyAppWeb.Endpoint,
            PowRateLimiter.EtsRateLimiter
          ]

          opts = [strategy: :one_for_one, name: MyAppWeb.Supervisor]
          Supervisor.start_link(children, opts)
        end

        # ...
      end

  ## Configuration

  - `:ttl` - The TTL in miliseconds that a rate limit count should exists since
    the most recent hit, optional, defaults to 30 minutes
  - `:sweep_interval` - The amount of miliseconds between sweep intervals to
    clear out expired counts, optional, defaults to 1 minutes
  - `:limit` - The number of maximum hits permitted before rate limiting,
    optional, defaults to 100
  - `:namespace` - The namespace to store the rate limits under, optional,
    defaults to "rate_count"
  """
  use GenServer

  alias Pow.Config

  @behaviour PowRateLimiter.Engine
  @ets_cache_tab __MODULE__

  @ttl :timer.minutes(30)
  @sweep_interval :timer.minutes(1)
  @limit 100

  @spec start_link(Config.t()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl PowRateLimiter.Engine
  def increase_rate_check(config, _conn, fingerprint) do
    key   = ets_key(config, fingerprint)
    limit = Config.get(config, :limit, @limit)
    ttl   = Config.get(config, :ttl, @ttl)
    now   = timestamp()

    case GenServer.call(__MODULE__, {:increase_count, key, now, ttl}) do
      {:ok, count, last_update, ttl} when count > limit -> {:deny, {count, last_update, ttl}}
      {:ok, count, last_update, ttl}                    -> {:allow, {count, last_update, ttl}}
    end
  end

  @impl PowRateLimiter.Engine
  def clear_rate(config, _conn, fingerprint) do
    key = ets_key(config, fingerprint)

    GenServer.call(__MODULE__, {:clear_count, key})
  end

  # Callbacks

  @impl GenServer
  def init(config) do
    table_init(config)

    {:ok, %{config: config}}
  end

  @impl GenServer
  def handle_call({:increase_count, key, now, ttl}, _from, state) do
    [count, now, ttl] = :ets.update_counter(@ets_cache_tab, key, [{2, 1}, {3, 1, 0, now}, {4, 1, 0, ttl}], {key, 0, now, ttl})

    {:reply, {:ok, count, now, ttl}, state}
  end

  @impl GenServer
  def handle_call({:clear_count, key}, _from, state) do
    :ets.delete(@ets_cache_tab, key)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:sweep, sweep_interval}, state) do
    now = timestamp()

    :ets.select_delete(@ets_cache_tab, [{
      {:_, :_, :"$1", :"$2"},
      [{:<, :"$1", {:-, now, :"$2"}}],
      [true]
    }])

    Process.send_after(self(), {:sweep, sweep_interval}, sweep_interval)

    {:noreply, state}
  end

  defp table_init(config) do
    sweep_interval = Config.get(config, :sweep_interval, @sweep_interval)

    :ets.new(@ets_cache_tab, [:named_table, :ordered_set, :public])

    Process.send_after(self(), {:sweep, sweep_interval}, sweep_interval)
  end

  defp timestamp(), do: :os.system_time(:millisecond)

  defp ets_key(config, key) do
    namespace = Config.get(config, :namespace, "rate_count")

    "#{namespace}:#{key}"
  end
end

defmodule PowPersistentSession.Plug.Base do
  @moduledoc """
  Base module for setting up persistent session plugs.

  Any writes to backend store or client should occur in `:before_send` callback
  as defined in `Plug.Conn`. To ensure that the callbacks are called in the
  order they were set, a `register_before_send/2` function is used to set
  callbacks instead of `Plug.Conn.register_before_send/2`.

  See `PowPersistentSession.Plug.Cookie` for an implementation example.

  ## Configuration options

    * `:persistent_session_store` - the persistent session store. This value
      defaults to
      `{PowPersistentSession.Store.PersistentSessionCache, backend: Pow.Store.Backend.EtsCache}`.
      The `Pow.Store.Backend.EtsCache` backend store can be changed with the
      `:cache_store_backend` option.

    * `:cache_store_backend` - the backend cache store. This value defaults to
      `Pow.Store.Backend.EtsCache`.

    * `:persistent_session_ttl` - integer value in milliseconds for TTL of
      persistent session in the backend store. This defaults to 30 days in
      miliseconds.
  """

  alias Plug.Conn
  alias Pow.{Config, Plug, Store.Backend.EtsCache}
  alias PowPersistentSession.Store.PersistentSessionCache

  @callback init(Config.t()) :: Config.t()
  @callback call(Conn.t(), Config.t()) :: Conn.t()
  @callback authenticate(Conn.t(), Config.t()) :: Conn.t()
  @callback create(Conn.t(), map(), Config.t()) :: Conn.t()

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      @before_send_private_key String.to_atom(Macro.underscore(__MODULE__) <> "/before_send")

      import unquote(__MODULE__)

      @impl true
      def init(config), do: config

      @impl true
      def call(conn, config) do
        config =
          conn
          |> Plug.fetch_config()
          |> Config.merge(config)
        conn   = Conn.put_private(conn, :pow_persistent_session, {__MODULE__, config})

        conn
        |> Plug.current_user(config)
        |> maybe_authenticate(conn, config)
        |> Conn.register_before_send(fn conn ->
          conn.private
          |> Map.get(@before_send_private_key, [])
          |> Enum.reduce(conn, & &1.(&2))
        end)
      end

      defp maybe_authenticate(nil, conn, config), do: authenticate(conn, config)
      defp maybe_authenticate(_user, conn, _config), do: conn

      defp register_before_send(conn, callback) do
        callbacks = Map.get(conn.private, @before_send_private_key, []) ++ [callback]

        Conn.put_private(conn, @before_send_private_key, callbacks)
      end
    end
  end

  @spec store(Config.t()) :: {module(), Config.t()}
  def store(config) do
    case Config.get(config, :persistent_session_store) do
      {store, store_config} -> {store, store_opts(config, store_config)}
      nil                   -> {PersistentSessionCache, store_opts(config)}
    end
  end

  defp store_opts(config, store_config \\ []) do
    store_config
    |> Keyword.put_new(:backend, Config.get(config, :cache_store_backend, EtsCache))
    |> Keyword.put_new(:ttl, ttl(config))
    |> Keyword.put_new(:pow_config, config)
  end

  @ttl :timer.hours(24) * 30

  @doc false
  def ttl(config), do: Config.get(config, :persistent_session_ttl, @ttl)
end

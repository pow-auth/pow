defmodule PowPersistentSession.Plug.Base do
  @moduledoc """
  Base module for setting up persistent session plugs.

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

  @callback authenticate(Conn.t(), Config.t()) :: Conn.t()
  @callback create(Conn.t(), map(), Config.t()) :: Conn.t()

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      import unquote(__MODULE__)

      @spec init(Config.t()) :: Config.t()
      def init(config), do: config

      @spec call(Conn.t(), Config.t()) :: Conn.t()
      def call(conn, config) do
        config =
          conn
          |> Plug.fetch_config()
          |> Config.merge(config)

        conn
        |> Conn.put_private(:pow_persistent_session, {__MODULE__, config})
        |> authenticate(config)
      end
    end
  end

  @spec store(Config.t()) :: {module(), Config.t()}
  def store(config) do
    case Config.get(config, :persistent_session_store, default_store(config)) do
      {store, store_config} -> {store, store_config}
      store                 -> {store, []}
    end
  end

  defp default_store(config) do
    backend = Config.get(config, :cache_store_backend, EtsCache)
    ttl     = ttl(config)

    {PersistentSessionCache, [backend: backend, ttl: ttl]}
  end

  @ttl :timer.hours(24) * 30

  @doc false
  def ttl(config), do: Config.get(config, :persistent_session_ttl, @ttl)
end

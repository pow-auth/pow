defmodule Pow.Plug.Base do
  @moduledoc """
  This plug macro will set `:pow_config` as private, and attempt to fetch and
  assign a user in the connection if it has not already been assigned. The user
  will be assigned automatically in any of the operations.

  Any writes to backend store or client should occur in `:before_send` callback
  as defined in `Plug.Conn`. To ensure that the callbacks are called in the
  order they were set, a `register_before_send/2` function is used to set
  callbacks instead of `Plug.Conn.register_before_send/2`.

  ## Configuration options

    * `:credentials_cache_store` - the credentials cache store. This value defaults to
      `{Pow.Store.CredentialsCache, backend: Pow.Store.Backend.EtsCache}`. The
      `Pow.Store.Backend.EtsCache` backend store can be changed with the
      `:cache_store_backend` option.

    * `:cache_store_backend` - the backend cache store. This value defaults to
      `Pow.Store.Backend.EtsCache`.

  ## Example

      defmodule MyAppWeb.Pow.CustomPlug do
        use Pow.Plug.Base

        @impl true
        def fetch(conn, _config) do
          user = fetch_user_from_cookie(conn)

          {conn, user}
        end

        @impl true
        def create(conn, user, _config) do
          conn = update_cookie(conn, user)

          {conn, user}
        end

        @impl true
        def delete(conn, _config) do
          delete_cookie(conn)
        end
      end
  """
  alias Plug.Conn
  alias Pow.{Config, Plug, Store.Backend.EtsCache, Store.CredentialsCache}

  @callback init(Config.t()) :: Config.t()
  @callback call(Conn.t(), Config.t()) :: Conn.t()
  @callback fetch(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  @callback create(Conn.t(), map(), Config.t()) :: {Conn.t(), map()}
  @callback delete(Conn.t(), Config.t()) :: Conn.t()

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      @before_send_private_key String.to_atom(Macro.underscore(__MODULE__) <> "/before_send")

      import unquote(__MODULE__)

      @doc false
      @impl true
      def init(config), do: config

      @doc """
      Configures the connection for Pow, and fetches user.

      If no options have been passed to the plug, the existing configuration
      will be pulled with `Pow.Plug.fetch_config/1`

      `:plug` is appended to the passed configuration, so the current plug will
      be used in any subsequent calls to create, update and delete user
      credentials from the connection. The configuration is then set for the
      conn with `Pow.Plug.put_config/2`.

      If a user can't be fetched with `Pow.Plug.current_user/2`, `do_fetch/2`
      will be called.
      """
      @impl true
      def call(conn, []), do: call(conn, Plug.fetch_config(conn))
      def call(conn, config) do
        config = put_plug(config)
        conn   = Plug.put_config(conn, config)

        conn
        |> Plug.current_user(config)
        |> maybe_fetch_user(conn, config)
        |> Conn.register_before_send(fn conn ->
          conn.private
          |> Map.get(@before_send_private_key, [])
          |> Enum.reduce(conn, & &1.(&2))
        end)
      end

      defp register_before_send(conn, callback) do
        callbacks = Map.get(conn.private, @before_send_private_key, []) ++ [callback]

        Conn.put_private(conn, @before_send_private_key, callbacks)
      end

      defp put_plug(config) do
        config
        |> Config.put(:plug, __MODULE__)
        |> Config.put(:mod, __MODULE__) # TODO: Remove by 1.1.0, this is only for backwards compability
      end

      @doc """
      Calls `fetch/2` and assigns the current user to the conn.

      The user is assigned to the conn with `Pow.Plug.assign_current_user/3`.
      """
      def do_fetch(conn, config) do
        conn
        |> fetch(config)
        |> assign_current_user(config)
      end

      @doc """
      Calls `create/3` and assigns the current user.

      The user is assigned to the conn with `Pow.Plug.assign_current_user/3`.
      """
      def do_create(conn, user, config) do
        conn
        |> create(user, config)
        |> assign_current_user(config)
      end

      @doc """
      Calls `delete/2` and removes the current user assigned to the conn.

      The user assigned is removed from the conn with
      `Pow.Plug.assign_current_user/3`.
      """
      def do_delete(conn, config) do
        conn
        |> delete(config)
        |> remove_current_user(config)
      end

      defp maybe_fetch_user(nil, conn, config), do: do_fetch(conn, config)
      defp maybe_fetch_user(_user, conn, _config), do: conn

      defp assign_current_user({conn, user}, config), do: Plug.assign_current_user(conn, user, config)

      defp remove_current_user(conn, config), do: Plug.assign_current_user(conn, nil, config)

      defoverridable unquote(__MODULE__)
    end
  end

  @spec store(Config.t()) :: {module(), Config.t()}
  def store(config) do
    config
    |> Config.get(:credentials_cache_store)
    |> Kernel.||(fallback_store(config))
    |> case do
      {store, store_config} -> {store, store_opts(config, store_config)}
      nil                   -> {CredentialsCache, store_opts(config)}
    end
  end

  # TODO: Remove by 1.1.0
  defp fallback_store(config) do
    case Config.get(config, :session_store) do
      nil ->
        nil

      value ->
        IO.warn("use of `:session_store` config value is deprecated, use `:credentials_cache_store` instead")
        value
    end
  end

  defp store_opts(config, store_config \\ []) do
    store_config
    |> Keyword.put_new(:backend, Config.get(config, :cache_store_backend, EtsCache))
    |> Keyword.put_new(:pow_config, config)
  end
end

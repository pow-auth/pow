defmodule Pow.Plug.Base do
  @moduledoc """
  This plug macro will set the `:pow_config` key, and attempt to fetch and
  assign a user in the connection if it has not already been assigned. The
  user will be assigned automatically in any of the operations.

  ## Example

      defmodule MyAppWeb.Pow.CustomPlug do
        use Pow.Plug.Base

        def fetch(conn, _config) do
          user = fetch_user_from_cookie(conn)

          {conn, user}
        end

        def create(conn, user, _config) do
          conn = update_cookie(conn, user)

          {conn, user}
        end

        def delete(conn, _config) do
          delete_cookie(conn)
        end
      end
  """
  alias Plug.Conn
  alias Pow.{Config, Plug}

  @callback init(Config.t()) :: Config.t()
  @callback call(Conn.t(), Config.t()) :: Conn.t()
  @callback fetch(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  @callback create(Conn.t(), map(), Config.t()) :: {Conn.t(), map()}
  @callback delete(Conn.t(), Config.t()) :: Conn.t()

  defmacro __using__(_opts) do
    quote do
      alias Pow.Plug.Base

      @behaviour Base

      def init(config), do: config

      def call(conn, config) do
        config = Pow.Config.put(config, :mod, __MODULE__)
        conn   = Pow.Plug.put_config(conn, config)

        conn
        |> Pow.Plug.current_user()
        |> maybe_fetch_user(conn)
      end

      @spec do_fetch(Conn.t()) :: Conn.t()
      def do_fetch(conn) do
        config = fetch_config(conn)

        conn
        |> fetch(config)
        |> assign_current_user(config)
      end

      @spec do_create(Conn.t(), map()) :: Conn.t()
      def do_create(conn, user) do
        config = fetch_config(conn)

        conn
        |> create(user, config)
        |> assign_current_user(config)
      end

      @spec do_delete(Conn.t()) :: Conn.t()
      def do_delete(conn) do
        config = fetch_config(conn)

        conn
        |> delete(config)
        |> remove_current_user(config)
      end

      defp maybe_fetch_user(nil, conn), do: do_fetch(conn)
      defp maybe_fetch_user(_user, conn), do: conn

      defp fetch_config(conn), do: Plug.fetch_config(conn)

      defp assign_current_user({conn, user}, config), do: Plug.assign_current_user(conn, user, config)

      defp remove_current_user(conn, config), do: Plug.assign_current_user(conn, nil, config)

      defoverridable Base
    end
  end
end

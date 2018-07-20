defmodule Pow.Plug.Base do
  @moduledoc """
  This plug macro will set the :pow_config key, and attempt to fetch and assign
  a user in the connection, if it has not already been assigned.

  You can use this to build your own pow plug:

  defmodule MyAppWeb.Pow.Plug do
    use Pow.Plug.Base

    def fetch(conn, config) do
      # Fetch user from conn
    end

    def create(conn, user, config) do
      # Create new user auth in conn
    end

    def delete(conn, config) do
      # Delete user auth from conn
    end

    The user will be assigned automatically in any of the operations.
  end
  """
  alias Plug.Conn
  alias Pow.Config

  @callback init(Config.t()) :: Config.t()
  @callback call(Conn.t(), Config.t()) :: Conn.t()
  @callback fetch(Conn.t(), Config.t()) :: map() | nil
  @callback create(Conn.t(), map(), Config.t()) :: Conn.t()
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

        case fetch(conn, config) do
          nil  -> conn
          user -> assign_user(conn, user, config)
        end
      end

      @spec do_create(Conn.t(), map()) :: Conn.t()
      def do_create(conn, user) do
        config = fetch_config(conn)

        conn
        |> create(user, config)
        |> assign_user(user, config)
      end

      @spec do_delete(Conn.t()) :: Conn.t()
      def do_delete(conn) do
        config = fetch_config(conn)

        conn
        |> delete(config)
        |> assign_user(nil, config)
      end

      defp maybe_fetch_user(nil, conn), do: do_fetch(conn)
      defp maybe_fetch_user(_user, conn), do: conn

      defp fetch_config(conn),
        do: Pow.Plug.fetch_config(conn)

      defp assign_user(conn, user, config),
        do: Pow.Plug.assign_current_user(conn, user, config)

      defoverridable Base
    end
  end
end

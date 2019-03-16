defmodule Pow.Phoenix.Controller do
  @moduledoc """
  Used with Pow Phoenix controllers to handle messages, routes and callbacks.

  ## Usage

      defmodule MyPowExtension.Phoenix.MyController do
        use Pow.Phoenix.Controller

        def process_new(conn, _params) do
          {:ok, :response, conn}
        end

        def respond_new({:ok, :response, conn}) do
          render(conn, "new.html")
        end
      end

  ## Configuration options

    * `:messages_backend` - See `Pow.Phoenix.Messages` for more.

    * `:routes_backend` - See `Pow.Phoenix.Routes` for more.

    * `:controller_callbacks` - See
      `Pow.Extension.Phoenix.ControllerCallbacks` for more.
  """
  alias Plug.Conn
  alias Pow.Config
  alias Pow.Phoenix.{Messages, PlugErrorHandler, Routes, ViewHelpers}
  alias Pow.Plug

  @doc false
  defmacro __using__(config) do
    quote do
      use Phoenix.Controller,
        namespace: Pow.Phoenix

      plug :pow_layout, unquote(config)

      @doc """
      See `Pow.Phoenix.Controller.action/3` for more.
      """
      @spec action(Conn.t(), Keyword.t()) :: Conn.t()
      def action(conn, _opts) do
        unquote(__MODULE__).action(__MODULE__, conn, conn.params)
      end

      defp require_authenticated(conn, _opts) do
        opts = Plug.RequireAuthenticated.init(error_handler: PlugErrorHandler)
        Plug.RequireAuthenticated.call(conn, opts)
      end

      defp require_not_authenticated(conn, _opts) do
        opts = Plug.RequireNotAuthenticated.init(error_handler: PlugErrorHandler)
        Plug.RequireNotAuthenticated.call(conn, opts)
      end

      defp pow_layout(conn, _config), do: ViewHelpers.layout(conn)

      unquote(__MODULE__).__define_helper_methods__()
    end
  end

  @doc false
  defmacro __define_helper_methods__() do
    quote do
      @doc """
      See `Pow.Phoenix.Controller.messages/2` for more.

      `Pow.Phoenix.Messages` is used as fallback.
      """
      @spec messages(Conn.t()) :: atom()
      def messages(conn) do
        unquote(__MODULE__).messages(conn, Messages)
      end

      @doc """
      See `Pow.Phoenix.Controller.routes/2` for more.

      `Pow.Phoenix.Routes` is used as fallback.
      """
      @spec routes(Conn.t()) :: atom()
      def routes(conn) do
        unquote(__MODULE__).routes(conn, Routes)
      end

      defoverridable messages: 1, routes: 1
    end
  end

  @doc """
  Handles the controller action call.

  If a `:controller_callbacks` module has been set in the configuration,
  then `before_process` and `before_respond` will be called on this module
  on all actions.
  """
  @spec action(atom(), Conn.t(), map()) :: Conn.t()
  def action(controller, %{private: private} = conn, params) do
    action    = private.phoenix_action
    config    = Plug.fetch_config(conn)
    callbacks = Config.get(config, :controller_callbacks)

    conn
    |> maybe_callback(callbacks, :before_process, controller, action, config)
    |> process_action(controller, action, params)
    |> maybe_callback(callbacks, :before_respond, controller, action, config)
    |> respond_action(controller, action)
  end

  defp process_action(conn, controller, action, params) do
    apply(controller, String.to_atom("process_#{action}"), [conn, params])
  end

  defp respond_action({:halt, conn}, _controller, _action), do: conn
  defp respond_action(results, controller, action) do
    apply(controller, String.to_atom("respond_#{action}"), [results])
  end

  defp maybe_callback(results, nil, _hook, _controller, _action, _config), do: results
  defp maybe_callback(results, callbacks, hook, controller, action, config) do
    apply(callbacks, hook, [controller, action, results, config])
  end

  @doc """
  Fetches messages backend from configuration, or use fallback.
  """
  @spec messages(Conn.t(), atom()) :: atom()
  def messages(conn, fallback) do
    conn
    |> Plug.fetch_config()
    |> Config.get(:messages_backend, fallback)
  end

  @doc """
  Fetches routes backend from configuration, or use fallback.
  """
  @spec routes(Conn.t(), atom()) :: atom()
  def routes(conn, fallback) do
    conn
    |> Plug.fetch_config()
    |> Config.get(:routes_backend, fallback)
  end

  @spec route_helper(atom()) :: binary()
  def route_helper(plug) do
    as             = Phoenix.Naming.resource_name(plug, "Controller")
    [base | _rest] = Module.split(plug)
    base           = Macro.underscore(base)

    "#{base}_#{as}"
  end
end

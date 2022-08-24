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

      import unquote(__MODULE__), only: [require_authenticated: 2, require_not_authenticated: 2, put_no_cache_header: 2]

      plug :pow_layout, unquote(config)

      def action(conn, _opts), do: unquote(__MODULE__).action(__MODULE__, conn, conn.params)

      defp pow_layout(conn, _config), do: ViewHelpers.layout(conn)

      unquote(__MODULE__).__define_helper_functions__()
    end
  end

  @doc false
  defmacro __define_helper_functions__ do
    quote do
      def messages(conn), do: unquote(__MODULE__).messages(conn, Messages)

      def routes(conn), do: unquote(__MODULE__).routes(conn, Routes)

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
    action = private.phoenix_action
    config = Plug.fetch_config(conn)
    callbacks = Config.get(config, :controller_callbacks)

    conn
    |> maybe_callback(callbacks, :before_process, controller, action, config)
    |> process_action(controller, action, params)
    |> maybe_callback(callbacks, :before_respond, controller, action, config)
    |> respond_action(controller, action)
  end

  defp process_action({:halt, conn}, _controller, _action, _params), do: {:halt, conn}
  defp process_action(conn, controller, action, params) do
    apply(controller, String.to_atom("process_#{action}"), [conn, params])
  end

  defp respond_action({:halt, conn}, _controller, _action), do: conn
  defp respond_action(results, controller, action) do
    apply(controller, String.to_atom("respond_#{action}"), [results])
  end

  defp maybe_callback({:halt, conn}, _callbacks, _hook, _controller, _action, _config),
    do: {:halt, conn}
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

  @doc """
  Ensures that user has been authenticated.

  `Pow.Phoenix.PlugErrorHandler` is used as error handler. See
  `Pow.Plug.RequireAuthenticated` for more.
  """
  @spec require_authenticated(Conn.t(), Keyword.t()) :: Conn.t()
  def require_authenticated(conn, _opts) do
    opts = Plug.RequireAuthenticated.init(error_handler: PlugErrorHandler)
    Plug.RequireAuthenticated.call(conn, opts)
  end

  @doc """
  Ensures that user hasn't been authenticated.

  `Pow.Phoenix.PlugErrorHandler` is used as error handler. See
  `Pow.Plug.RequireNotAuthenticated` for more.
  """
  @spec require_not_authenticated(Conn.t(), Keyword.t()) :: Conn.t()
  def require_not_authenticated(conn, _opts) do
    opts = Plug.RequireNotAuthenticated.init(error_handler: PlugErrorHandler)
    Plug.RequireNotAuthenticated.call(conn, opts)
  end

  @default_cache_control_header Conn.get_resp_header(struct(Conn), "cache-control")
  @no_cache_control_header      "no-cache, no-store, must-revalidate"

  @doc """
  Ensures that the page can't be cached in browser.

  This will add a "cache-control" header with
  "no-cache, no-store, must-revalidate" if the cache control header hasn't
  been changed from the default value in the `Plug.Conn` struct.
  """
  @spec put_no_cache_header(Conn.t(), Keyword.t()) :: Conn.t()
  def put_no_cache_header(conn, _opts) do
    conn
    |> Conn.get_resp_header("cache-control")
    |> case do
      @default_cache_control_header -> Conn.put_resp_header(conn, "cache-control", @no_cache_control_header)
      _any                          -> conn
    end
  end
end

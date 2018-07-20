defmodule Pow.Test.ExtensionMocks do
  defmacro __using__(opts) do
    base_module = __CALLER__.module
    extensions  = opts[:extensions] || []
    location    = Macro.Env.location(__ENV__)

    Module.create(Module.concat([base_module, Pow]),
    quote do
      alias unquote(base_module).RepoMock

      use Pow,
        user: unquote(base_module).Users.User,
        repo: RepoMock,
        extensions: unquote(extensions),
        cache_store_backend: Pow.Test.EtsCacheMock,
        mailer: Pow.Test.Phoenix.MailerMock,
        messages_backend: unquote(base_module).Phoenix.Messages
    end, location)

    Module.create(Module.concat([base_module, Users.User]),
    quote do
      use Ecto.Schema
      use unquote(base_module).Pow.Ecto.Schema

      schema "users" do
        pow_user_fields()

        timestamps()
      end
    end, location)

    Module.create(Module.concat([base_module, Phoenix.Router]),
    quote do
      use Phoenix.Router
      use unquote(base_module).Pow.Phoenix.Router

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_flash
        plug :protect_from_forgery
        plug :put_secure_browser_headers
      end

      scope "/" do
        pipe_through :browser

        pow_routes()
      end
    end, location)

    endpoint_module = Module.concat([base_module, Phoenix.Endpoint])
    error_view_module = Module.concat([base_module, Phoenix.ErrorView])
    endpoint_config = [
      render_errors: [view: error_view_module, accepts: ~w(html json)],
      secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2)]
    Application.put_env(:pow, endpoint_module, endpoint_config)

    Module.create(endpoint_module,
    quote do
      use Phoenix.Endpoint, otp_app: :pow

      def init(_key, _config), do: {:ok, unquote(endpoint_config)}

      plug Plug.RequestId
      plug Plug.Logger

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Poison

      plug Plug.MethodOverride
      plug Plug.Head

      plug Plug.Session,
        store: :cookie,
        key: "_binaryid_key",
        signing_salt: "secret"

      plug unquote(base_module).Pow.Plug.Session

      plug unquote(base_module).Phoenix.Router
    end, location)

    Module.create(Module.concat([base_module, Phoenix.ConnCase]),
    quote do
      use ExUnit.CaseTemplate
      alias Pow.Test.{EtsCacheMock, Phoenix.ControllerAssertions}
      alias unquote(base_module).Phoenix.{Endpoint, Router}

      using do
        quote do
          use Phoenix.ConnTest
          import ControllerAssertions

          alias Router.Helpers, as: Routes

          @endpoint Endpoint
        end
      end

      setup_all _opts do
        {:ok, _pid} = Endpoint.start_link()

        :ok
      end

      setup _tags do
        EtsCacheMock.init()
        {:ok, conn: Phoenix.ConnTest.build_conn()}
      end
    end, location)

    Module.create(Module.concat([base_module, Phoenix.LayoutView]),
    quote do
      use Pow.Test.Phoenix.Web, :view
    end, location)

    Module.create(Module.concat([base_module, Phoenix.ErrorView]),
    quote do
      def render("500.html", _assigns), do: "500.html"
      def render("400.html", _assigns), do: "400.html"
      def render("404.html", _assigns), do: "404.html"
    end, location)

    Module.create(Module.concat([base_module, Phoenix.Messages]),
    quote do
      use unquote(base_module).Pow.Phoenix.Messages
    end, location)

    quote do
    end
  end
end

defmodule Pow.Test.ExtensionMocks do
  @moduledoc false
  defmacro __using__(opts) do
    context_module = __CALLER__.module
    web_module     = String.to_atom("#{context_module}Web")

    Code.eval_quoted(quote do
      Application.put_env(unquote(context_module), :pow,
        user: Module.concat([unquote(context_module), Users.User]),
        repo: Module.concat([unquote(context_module), RepoMock]),
        cache_store_backend: Pow.Test.EtsCacheMock,
        mailer_backend: Pow.Test.Phoenix.MailerMock,
        messages_backend: Module.concat([unquote(web_module), Phoenix.Messages]),
        extensions: unquote(opts)[:extensions] || [],
        controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks)
    end)

    module = Module.concat([context_module, Users.User])
    quoted = quote do
      use Ecto.Schema
      use Pow.Ecto.Schema, otp_app: unquote(context_module)
      use Pow.Extension.Ecto.Schema

      schema "users" do
        pow_user_fields()

        timestamps()
      end

      def changeset(user_or_changeset, attrs) do
        user_or_changeset
        |> pow_changeset(attrs)
        |> pow_extension_changeset(attrs)
      end
    end
    Module.create(module, quoted, Macro.Env.location(__ENV__))

    module = Module.concat([web_module, Phoenix.Router])
    quoted = quote do
      use Phoenix.Router
      use Pow.Phoenix.Router
      use Pow.Extension.Phoenix.Router, otp_app: unquote(context_module)

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
        pow_extension_routes()
      end
    end
    Module.create(module, quoted, Macro.Env.location(__ENV__))

    endpoint_module = Module.concat([web_module, Phoenix.Endpoint])
    error_view_module = Module.concat([web_module, Phoenix.ErrorView])
    endpoint_config = [
      render_errors: [view: error_view_module, accepts: ~w(html json)],
      secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2)]
    Application.put_env(:pow, endpoint_module, endpoint_config)

    quoted = quote do
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

      plug Pow.Plug.Session, otp_app: unquote(context_module)

      plug unquote(web_module).Phoenix.Router
    end
    Module.create(endpoint_module, quoted, Macro.Env.location(__ENV__))

    module = Module.concat([web_module, Phoenix.ConnCase])
    quoted = quote do
      use ExUnit.CaseTemplate
      alias Pow.Test.{EtsCacheMock, Phoenix.ControllerAssertions}
      alias unquote(web_module).Phoenix.{Endpoint, Router}

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
    end
    Module.create(module, quoted, Macro.Env.location(__ENV__))

    module = Module.concat([web_module, Phoenix.LayoutView])
    quoted = quote do
      use Pow.Test.Phoenix.Web, :view
    end
    Module.create(module, quoted, Macro.Env.location(__ENV__))

    module = Module.concat([web_module, Phoenix.ErrorView])
    quoted = quote do
      def render("500.html", _assigns), do: "500.html"
      def render("400.html", _assigns), do: "400.html"
      def render("404.html", _assigns), do: "404.html"
    end
    Module.create(module, quoted, Macro.Env.location(__ENV__))

    module = Module.concat([web_module, Phoenix.Messages])
    quoted = quote do
      use Pow.Phoenix.Messages
      use Pow.Extension.Phoenix.Messages,
        extensions: unquote(opts)[:extensions]
    end
    Module.create(module, quoted, Macro.Env.location(__ENV__))

    quote do
    end
  end
end

defmodule Pow.Test.ExtensionMocks do
  @moduledoc false
  defmacro __using__(opts) do
    context_module = __CALLER__.module
    web_module     = String.to_atom("#{context_module}Web")

    module = Module.concat([context_module, Users.User])
    quoted = quote do
      use Ecto.Schema
      use Pow.Ecto.Schema,
        extensions: unquote(opts)[:extensions]
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

    module = Module.concat([web_module, Phoenix.Endpoint])

    quoted = quote do
      use Phoenix.Endpoint, otp_app: unquote(context_module)

      plug Plug.RequestId
      plug Plug.Logger

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Phoenix.json_library()

      plug Plug.MethodOverride
      plug Plug.Head

      plug Plug.Session,
        store: :cookie,
        key: "_binaryid_key",
        signing_salt: "secret"

      plug Pow.Plug.Session, otp_app: unquote(context_module)

      if Code.ensure_compiled?(unquote(opts[:plug])) do
        plug unquote(opts[:plug])
      end

      plug unquote(web_module).Phoenix.Router
    end
    Module.create(module, quoted, Macro.Env.location(__ENV__))

    module = Module.concat([web_module, Phoenix.ConnCase])
    quoted = quote do
      use ExUnit.CaseTemplate
      alias Pow.Test.Phoenix.ControllerAssertions
      alias unquote(web_module).Phoenix.{Endpoint, Router}

      using do
        quote do
          use Phoenix.ConnTest
          import ControllerAssertions

          alias Router.Helpers, as: Routes

          @endpoint Endpoint
        end
      end

      @ets Application.get_env(unquote(context_module), :pow)[:cache_store_backend]

      setup _tags do
        @ets.init()
        {:ok, conn: Phoenix.ConnTest.build_conn(), ets: @ets}
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

        def signed_in(_conn), do: "signed_in"
    end
    Module.create(module, quoted, Macro.Env.location(__ENV__))

    quote do
    end
  end
end

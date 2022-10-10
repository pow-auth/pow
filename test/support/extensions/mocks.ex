defmodule Pow.Test.ExtensionMocks do
  @moduledoc """
  Dynamically creates modules required for extension tests. This is due to
  compile-time configuration of Phoenix and Ecto modules.

  Since Phoenix and Plug modules in Pow are tested without Ecto integration,
  an Ecto repo mock module is also necessary.

  ## Example

    defmodule PowPersistentSession.Test do
      @moduledoc false
      use Pow.Test.ExtensionMocks,
        extensions: [PowPersistentSession],
        plug: PowPersistentSession.Plug.Cookie
    end

    defmodule PowPersistentSession.Test.RepoMock do
      @moduledoc false
      alias Pow.Ecto.Schema.Password
      alias PowPersistentSession.Test.Users.User

      def get_by(User, id: 1), do: %User{id: 1}
      def get_by(User, id: -1), do: nil

      def get_by(User, email: "test@example.com"),
        do: %User{id: 1, password_hash: Password.pbkdf2_hash("secret1234")}
    end
  """

  defmacro __using__(opts) do
    context_module = __CALLER__.module
    web_module     = String.to_atom("#{context_module}Web")
    cache_backend  = Pow.Test.EtsCacheMock
    extensions     = opts[:extensions]
    user_module    = Module.concat([context_module, Users.User])
    config         = [
      user: user_module,
      repo: Module.concat([context_module, RepoMock]),
      cache_store_backend: cache_backend,
      mailer_backend: Pow.Test.Phoenix.MailerMock,
      messages_backend: Module.concat([web_module, Phoenix.Messages]),
      routes_backend: Module.concat([web_module, Phoenix.Routes]),
      extensions: extensions,
      controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
      message_verifier: Pow.Test.MessageVerifier
    ]

    __user_schema__(context_module, extensions)
    __phoenix_endpoint__(web_module, config, opts)
    __phoenix_views__(web_module)
    __conn_case__(web_module, cache_backend)
    __messages__(web_module, extensions)
    __routes__(web_module)

    quote do
      @config unquote(config)

      def pow_config, do: @config
    end
  end

  def __user_schema__(context_module, extensions, opts \\ []) do
    module = Module.concat(context_module, Keyword.get(opts, :module, Users.User))
    config = Keyword.take(opts, [:user_id_field]) ++ [extensions: extensions]

    quoted = quote do
      use Ecto.Schema
      use Pow.Ecto.Schema, unquote(config)
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
  end

  def __phoenix_endpoint__(web_module, config, opts) do
    module = Module.concat([web_module, Phoenix.Router])
    quoted = quote do
      use Phoenix.Router
      use Pow.Phoenix.Router
      use Pow.Extension.Phoenix.Router, unquote(config)

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
      defmodule SessionPlugHelper do
        @moduledoc false

        alias Pow.Plug.Session

        def init(config), do: Session.init(config)

        def call(conn, config), do: Session.call(conn, Keyword.merge(config, conn.private[:pow_test_config] || []))
      end

      use Phoenix.Endpoint, otp_app: :pow

      @session_options [
        store: :cookie,
        key: "_binaryid_key",
        signing_salt: "secret"
      ]

      @pow_config unquote(config)

      plug Plug.RequestId
      plug Plug.Logger

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Phoenix.json_library()

      plug Plug.MethodOverride
      plug Plug.Head

      plug Plug.Session, @session_options
      plug SessionPlugHelper, @pow_config
      if unquote(opts[:plug]) do
        Code.ensure_compiled(unquote(opts[:plug]))
        plug unquote(opts[:plug])
      end
      plug unquote(web_module).Phoenix.Router
    end

    Module.create(module, quoted, Macro.Env.location(__ENV__))
  end

  def __conn_case__(web_module, cache_backend) do
    module = Module.concat([web_module, Phoenix.ConnCase])
    quoted = quote do
      use ExUnit.CaseTemplate
      alias Pow.Test.Phoenix.ControllerAssertions
      alias unquote(web_module).Phoenix.{Endpoint, Router}

      using do
        quote do
          import Plug.Conn
          import Phoenix.ConnTest, except: [get_flash: 2]
          import Pow.Test.Phoenix.ConnCase, only: [get_flash: 2]
          import ControllerAssertions

          alias Router.Helpers, as: Routes

          @endpoint Endpoint
        end
      end

      setup do
        unquote(cache_backend).init()
        {:ok, conn: Phoenix.ConnTest.build_conn(), ets: unquote(cache_backend)}
      end
    end

    Module.create(module, quoted, Macro.Env.location(__ENV__))
  end

  def __phoenix_views__(web_module) do
    module = Module.concat([web_module, Phoenix.LayoutView])
    quoted = quote do
      use Pow.Test.Phoenix.Web, :view
    end

    Module.create(module, quoted, Macro.Env.location(__ENV__))
  end

  def __messages__(web_module, extensions) do
    module = Module.concat([web_module, Phoenix.Messages])
    quoted = quote do
      use Pow.Phoenix.Messages
      use Pow.Extension.Phoenix.Messages,
        extensions: unquote(extensions)

      def signed_in(_conn), do: "signed_in"
      def user_has_been_created(_conn), do: "user_created"
    end

    Module.create(module, quoted, Macro.Env.location(__ENV__))
  end

  def __routes__(web_module) do
    module = Module.concat([web_module, Phoenix.Routes])
    quoted = quote do
      use Pow.Phoenix.Routes

      def after_sign_in_path(_conn), do: "/after_signed_in"
      def after_registration_path(_conn), do: "/after_registration"
    end

    Module.create(module, quoted, Macro.Env.location(__ENV__))
  end
end

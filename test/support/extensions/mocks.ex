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
      extensions: extensions,
      controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks]

    __user_schema__(context_module, extensions)
    __phoenix_endpoint__(web_module, config, opts)
    __phoenix_views__(web_module)
    __conn_case__(web_module, cache_backend)
    __messages__(web_module, extensions)

    quote do
      @config unquote(config)

      def pow_config(), do: @config
    end
  end

  def __user_schema__(context_module, extensions) do
    module = Module.concat([context_module, Users.User])
    quoted = quote do
      use Ecto.Schema
      use Pow.Ecto.Schema,
        extensions: unquote(extensions)
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
      use Phoenix.Endpoint, otp_app: :pow

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

      plug Pow.Plug.Session, unquote(config)

      if Code.ensure_compiled?(unquote(opts[:plug])) do
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
          use Phoenix.ConnTest
          import ControllerAssertions

          alias Router.Helpers, as: Routes

          @endpoint Endpoint
        end
      end

      @ets unquote(cache_backend)

      setup _tags do
        @ets.init()
        {:ok, conn: Phoenix.ConnTest.build_conn(), ets: @ets}
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
    end

    Module.create(module, quoted, Macro.Env.location(__ENV__))
  end
end

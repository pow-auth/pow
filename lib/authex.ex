defmodule Authex do
  @moduledoc """
  A module that provides authentication system for your Phoenix app.

  ## Usage

  Create `lib/my_project/authex.ex`:

      defmodule MyApp.Authex do
        use Authex,
          user: MyApp.Users.User,
          repo: MyApp.Repo
      end

  The following modules will be made available:

    - `MyApp.Authex.Ecto.Schema`
    - `MyApp.Authex.Phoenix.Router`
    - `MyApp.Authex.Phoenix.Messages`
    - `MyApp.Authex.Plug.Session`

  For extensions integration, `Authex.Extension.Phoenix.ControllerCallbacks`
  will also be automatically included in the configuration
  unless `:controller_callbacks_backend` has already been set.
  """
  alias Authex.Extension.Phoenix.ControllerCallbacks

  defmacro __using__(config) do
    quote do
      config = unquote(__MODULE__).__parse_config__(unquote(config))

      unquote(__MODULE__).__create_ecto_schema_mod__(__MODULE__, config)
      unquote(__MODULE__).__create_phoenix_router_mod__(__MODULE__, config)
      unquote(__MODULE__).__create_phoenix_messages_mod__(__MODULE__, config)
      unquote(__MODULE__).__create_plug_session_mod__(__MODULE__, config)
    end
  end

  def __parse_config__(config) do
    Keyword.put_new(config, :controller_callbacks, ControllerCallbacks)
  end

  defmacro __create_ecto_schema_mod__(mod, config) do
    quote do
      config = unquote(config)
      name   = unquote(mod).Ecto.Schema
      quoted = quote do
        defmacro __using__(_opts) do
          config = unquote(config)
          quote do
            use Authex.Ecto.Schema, unquote(config)
            use Authex.Extension.Ecto.Schema, unquote(config)

            def changeset(user, attrs) do
              user
              |> authex_changeset(attrs)
              |> authex_extension_changeset(attrs)
            end
          end
        end
      end

      Module.create(name, quoted, Macro.Env.location(__ENV__))
    end
  end

  defmacro __create_phoenix_router_mod__(mod, config) do
    quote do
      config = unquote(config)
      name   = unquote(mod).Phoenix.Router
      quoted = quote do
        config = unquote(config)

        defmacro __using__(_opts) do
          name   = unquote(name)
          config = unquote(config)
          quote do
            require Authex.Phoenix.Router
            use Authex.Extension.Phoenix.Router, unquote(config)
            import unquote(name)
          end
        end

        defmacro authex_routes do
          quote do
            Authex.Phoenix.Router.authex_routes()
            authex_extension_routes()
          end
        end
      end

      Module.create(name, quoted, Macro.Env.location(__ENV__))
    end
  end

  defmacro __create_phoenix_messages_mod__(mod, config) do
    quote do
      config = unquote(config)
      name   = unquote(mod).Phoenix.Messages
      quoted = quote do
        config = unquote(config)

        defmacro __using__(_opts) do
          config = unquote(config)
          quote do
            use Authex.Phoenix.Messages
            use Authex.Extension.Phoenix.Messages,
              unquote(config)
          end
        end
      end

      Module.create(name, quoted, Macro.Env.location(__ENV__))
    end
  end

  defmacro __create_plug_session_mod__(mod, config) do
    quote do
      name   = unquote(mod).Plug.Session
      mod    = Authex.Plug.Session
      config = unquote(config)
      quoted = quote do
        def init(_opts), do: unquote(mod).init(unquote(config))
        def call(conn, _opts), do: unquote(mod).call(conn, unquote(config))
        def fetch(conn, _opts), do: unquote(mod).fetch(conn, unquote(config))
        def create(conn, _opts), do: unquote(mod).create(conn, unquote(config))
        def delete(conn, _opts), do: unquote(mod).delete(conn, unquote(config))
      end

      Module.create(name, quoted, Macro.Env.location(__ENV__))
    end
  end

  @spec config() :: Keyword.t()
  def config(), do: Application.get_env(:authex, Authex, [])
end

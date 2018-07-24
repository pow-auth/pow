defmodule Pow do
  @moduledoc """
  A module that provides authentication system for your Phoenix app.

  ## Usage

  Create `lib/my_project/pow.ex`:

      defmodule MyApp.Pow do
        use Pow,
          user: MyApp.Users.User,
          repo: MyApp.Repo
      end

  The following modules will be made available:

    - `MyApp.Pow.Ecto.Schema`
    - `MyApp.Pow.Phoenix.Router`
    - `MyApp.Pow.Phoenix.Messages`
    - `MyApp.Pow.Plug.Session`

  For extensions integration, `Pow.Extension.Phoenix.ControllerCallbacks`
  will also be automatically included in the configuration
  unless `:controller_callbacks_backend` has already been set.
  """
  alias Pow.Extension.Phoenix.ControllerCallbacks

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
            use Pow.Ecto.Schema, unquote(config)
            use Pow.Extension.Ecto.Schema, unquote(config)

            @spec changeset(Ecto.Schema.t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
            def changeset(user_or_changeset, attrs) do
              user_or_changeset
              |> pow_changeset(attrs)
              |> pow_extension_changeset(attrs)
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
            require Pow.Phoenix.Router
            use Pow.Extension.Phoenix.Router, unquote(config)
            import unquote(name)
          end
        end

        defmacro pow_routes do
          quote do
            Pow.Phoenix.Router.pow_routes()
            pow_extension_routes()
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
            use Pow.Phoenix.Messages
            use Pow.Extension.Phoenix.Messages,
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
      mod    = Pow.Plug.Session
      config = unquote(config)
      quoted = quote do
        def init(_opts), do: unquote(mod).init(unquote(config))
        def call(conn, opts), do: unquote(mod).call(conn, opts)
        def fetch(conn, _opts), do: unquote(mod).fetch(conn, unquote(config))
        def create(conn, _opts), do: unquote(mod).create(conn, unquote(config))
        def delete(conn, _opts), do: unquote(mod).delete(conn, unquote(config))
      end

      Module.create(name, quoted, Macro.Env.location(__ENV__))
    end
  end
end

defmodule Pow do
  @moduledoc """
  A module that provides authentication system for your app.

  ## Usage

  Create `lib/my_project/pow.ex`:

      defmodule MyApp.Pow do
        use Pow, :context,
          extensions: [PowExtensionOne, PowExtensionTwo]
      end

  The following modules will be made available:

    - `MyApp.Pow.Ecto.Schema`
  """
  defmacro __using__(config) do
    quote do
      unquote(__MODULE__).__create_ecto_schema_mod__(__MODULE__, unquote(config))
    end
  end

  defmacro __create_ecto_schema_mod__(mod, config) do
    quote do
      config = unquote(config)
      name   = unquote(mod).Ecto.Schema
      quoted = quote do
        defmacro __using__(config) do
          config = Keyword.merge(unquote(config), config)
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
end

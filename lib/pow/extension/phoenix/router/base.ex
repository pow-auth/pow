defmodule Pow.Extension.Phoenix.Router.Base do
  @moduledoc """
  Used for extensions to extend routes.

  ## Usage

      defmodule MyPowExtension.Phoenix.Router do
        use Pow.Extension.Phoenix.Router.Base

        defmacro routes(_config) do
          quote location: :keep do
            resources "/reset-password", TestController, only: [:new]
          end
        end
      end

  A macro `MyPowExtension.Phoenix.Router.scoped_routes/1` will be created that
  wraps the routes inside a scope with the extension as namespace similar to:

      scope "/", MyPowExtension.Phoenix, as: "my_pow_extension" do
        MyPowExtension.Phoenix.Router.routes(config)
      end
  """
  @macrocallback routes(Pow.Config.t()) :: Macro.t()

  @doc false
  defmacro __using__(_opts) do
    extension = __extension__(__CALLER__.module)

    quote do
      @behaviour unquote(__MODULE__)

      unquote(__MODULE__).__create_scope_routes_function__(unquote(extension))
    end
  end

  defmacro __create_scope_routes_function__(extension) do
    quote do
      @doc false
      defmacro scoped_routes(config) do
        phoenix_module = unquote(extension).Phoenix
        namespace      = unquote(__MODULE__).__namespace__(unquote(extension))

        quote location: :keep do
          require unquote(__MODULE__)

          scope "/", unquote(phoenix_module), as: unquote(namespace) do
            unquote(__MODULE__).routes(unquote(config))
          end
        end
      end
    end
  end

  @doc false
  def __extension__(modules) do
    ["Router", "Phoenix" | extension] =
      modules
      |> Module.split()
      |> Enum.reverse()

    extension
    |> Enum.reverse()
    |> Module.concat()
  end

  @doc false
  def __namespace__(extension) do
    extension
    |> Module.split()
    |> Enum.join()
    |> Macro.underscore()
  end
end

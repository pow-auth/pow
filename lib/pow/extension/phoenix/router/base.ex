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
  alias Pow.Extension.Config

  @macrocallback routes(Pow.Config.t()) :: Macro.t()

  defmacro __using__(_opts) do
    extension      = __MODULE__.__extension__(__CALLER__.module)
    phoenix_module = Module.concat([extension, "Phoenix"])
    namespace      = Config.underscore_extension(extension)

    quote do
      @behaviour unquote(__MODULE__)

      defmacro scoped_routes(config) do
        phoenix_module = unquote(phoenix_module)
        namespace      = unquote(namespace)

        quote location: :keep do
          require unquote(__MODULE__)

          scope "/", unquote(phoenix_module), as: unquote(namespace) do
            unquote(__MODULE__).routes(unquote(config))
          end
        end
      end
    end
  end

  def __extension__(module) do
    [_router, _phoenix | extension] =
      module
      |> Module.split()
      |> Enum.reverse()

    extension
    |> Enum.reverse()
    |> Module.concat()
  end
end

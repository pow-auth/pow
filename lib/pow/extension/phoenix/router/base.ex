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
  """
  alias Pow.Config

  @macrocallback routes(Config.t()) :: Macro.t()

  defmacro __using__(_opts) do
    extension      = __MODULE__.__extension__(__CALLER__.module)
    phoenix_module = Module.concat([extension, "Phoenix"])
    namespace      = Pow.Extension.Config.underscore_extension(extension)
    routes_method  = String.to_atom("#{namespace}_routes")

    quote do
      @behaviour unquote(__MODULE__)

      defmacro unquote(routes_method)(config) do
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

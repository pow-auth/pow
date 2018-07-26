defmodule Pow.Extension.Phoenix.Router.Base do
  @moduledoc """
  Used for extensions to extend routes.

  ## Usage

      defmodule MyPowExtension.Phoenix.Router do
        use Pow.Extension.Phoenix.Router.Base

        def routes(_config) do
          quote location: :keep do
            resources "/reset-password", TestController, only: [:new]
          end
        end
      end
  """
  alias Pow.Config

  @callback routes(Config.t()) :: Macro.t()

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
        quoted         = __MODULE__.routes(config)

        quote location: :keep do
          scope "/", unquote(phoenix_module), as: unquote(namespace) do
            unquote(quoted)
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

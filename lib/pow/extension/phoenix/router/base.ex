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
    quote do
      @behaviour unquote(__MODULE__)
    end
  end
end

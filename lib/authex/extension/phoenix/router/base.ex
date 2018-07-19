defmodule Authex.Extension.Phoenix.Router.Base do
  @moduledoc """
  Used for extensions to extend routes.

  ## Usage

      defmodule MyAuthexExtension.Phoenix.Router do
        use Authex.Extension.Phoenix.Router.Base

        def routes(_config) do
          quote location: :keep do
            resources "/reset-password", TestController, only: [:new]
          end
        end
      end
  """
  alias Authex.Config

  @callback routes(Config.t()) :: Macro.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end
end

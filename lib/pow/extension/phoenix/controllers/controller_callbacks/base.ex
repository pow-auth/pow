defmodule Pow.Extension.Phoenix.ControllerCallbacks.Base do
  @moduledoc """
  Used for the Phoenix Controller Callbacks module in extensions.

  ## Usage

      defmodule MyPowExtension.Phoenix.ControllerCallbacks do
        use Pow.Extension.Phoenix.ControllerCallbacks.Base

        @impl true
        def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, user, conn}, _config) do
          {:ok, user, conn}
        end
      end
  """
  alias Pow.{Config, Extension.Phoenix.Controller.Base, Phoenix.Controller}

  @callback before_process(atom(), atom(), any(), Config.t()) :: any()
  @callback before_respond(atom(), atom(), any(), Config.t()) :: any()

  @doc false
  defmacro __using__(config) do
    quote do
      @behaviour unquote(__MODULE__)

      require Base
      require Controller

      Base.__define_helper_functions__(unquote(config))
      Controller.__define_helper_functions__()

      @before_compile unquote(__MODULE__)
    end
  end

  @doc false
  defmacro __before_compile__(_opts) do
    for hook <- [:before_process, :before_respond] do
      quote do
        @impl true
        def unquote(hook)(_controller, _action, res, _config), do: res
      end
    end
  end
end

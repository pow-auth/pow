defmodule Authex.Phoenix.HTML do
  @moduledoc """
  Module that handles rendering of registration and login forms.
  """
  alias Authex.Phoenix.HTML.Template

  for {controller, action} <- [{:registration, :new},
               {:registration, :edit},
               {:session, :new}] do
    template = Template.template(:form, controller, action)

    @spec form(unquote(controller), unquote(action)) :: Macro.t()
    def form(unquote(controller), unquote(action)) do
      EEx.compile_string(unquote(template), engine: Phoenix.HTML.Engine)
    end
  end
end

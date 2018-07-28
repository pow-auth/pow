defmodule PowEmailConfirmation.Phoenix.Router do
  @moduledoc false
  use Pow.Extension.Phoenix.Router.Base

  defmacro routes(_config) do
    quote location: :keep do
      resources "/confirm-email", ConfirmationController, only: [:show]
    end
  end
end

defmodule PowInvitation.Phoenix.Router do
  @moduledoc false
  use Pow.Extension.Phoenix.Router.Base

  alias Pow.Phoenix.Router

  defmacro routes(_config) do
    quote location: :keep do
      Router.pow_resources "/invitations", InvitationController, only: [:new, :create, :show, :edit, :update]
    end
  end
end

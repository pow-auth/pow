defmodule PowInvitation.Phoenix.Messages do
  @moduledoc false

  def invalid_invitation(_conn), do: "The invitation doesn't exist."
  def invitation_email_sent(_conn), do: "An e-mail with invitation link has been sent."
end

defmodule PowInvitation.Test do
  @moduledoc false
  use Pow.Test.ExtensionMocks,
    extensions: [PowInvitation]

  Pow.Test.ExtensionMocks.__user_schema__(PowInvitation.PowEmailConfirmation.Test, [PowInvitation, PowEmailConfirmation])
end

defmodule PowEmailConfirmation.Test do
  @moduledoc false
  use Pow.Test.ExtensionMocks,
    extensions: [PowEmailConfirmation]

  extensions = [PowEmailConfirmation, PowInvitation]
  context    = PowEmailConfirmation.PowInvitation.Test
  config =
    @config
    |> Keyword.put(:extensions, extensions)
    |> Keyword.put(:user, Module.concat([context, Users.User]))
    |> Keyword.put(:repo, __MODULE__.RepoMock.Invitation)

  Pow.Test.ExtensionMocks.__user_schema__(context, extensions)
  Pow.Test.ExtensionMocks.__phoenix_endpoint__(String.to_atom("#{context}Web"), config, [])
end

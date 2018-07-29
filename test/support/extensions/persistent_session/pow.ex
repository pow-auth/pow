defmodule PowPersistentSession.Test do
  @moduledoc false
  use Pow.Test.ExtensionMocks,
    extensions: [PowPersistentSession],
    plug: PowPersistentSession.Plug.Cookie
end

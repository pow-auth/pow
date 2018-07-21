defmodule Pow.Store.CredentialsCache do
  @moduledoc """
  Default module for credentials session storage.
  """
  use Pow.Store.Base,
    ttl: :timer.minutes(30),
    namespace: "credentials"
end

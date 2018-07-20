defmodule Pow.Store.CredentialsCache do
  @moduledoc """
  Default module for credentials session storage.
  """
  use Pow.Store.Base,
    ttl: :timer.hours(48),
    namespace: "credentials"
end

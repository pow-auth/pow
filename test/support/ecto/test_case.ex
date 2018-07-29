defmodule Pow.Test.Ecto.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Pow.Test.Ecto.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})

    :ok
  end
end

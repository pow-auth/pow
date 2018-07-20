defmodule Pow.Test.Ecto.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Pow.Test.Ecto.Repo

  setup_all do
    create_test_database()
    {:ok, _pid} = Repo.start_link()
    Sandbox.mode(Repo, :manual)

    :ok
  end

  setup do
    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})

    :ok
  end

  defp create_test_database do
    Mix.Task.run "ecto.drop", ~w(--quiet -r Pow.Test.Ecto.Repo)
    Mix.Task.run "ecto.create", ~w(--quiet -r Pow.Test.Ecto.Repo)
    Mix.Task.run "ecto.migrate", ~w(--quiet -r Pow.Test.Ecto.Repo)
  end
end

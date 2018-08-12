Mix.shell(Mix.Shell.Process)
Logger.configure(level: :warn)

ExUnit.start()

Mix.Task.run("ecto.drop", ~w(--quiet -r Pow.Test.Ecto.Repo))
Mix.Task.run("ecto.create", ~w(--quiet -r Pow.Test.Ecto.Repo))
Mix.Task.run("ecto.migrate", ~w(--quiet -r Pow.Test.Ecto.Repo))

{:ok, _pid} = Pow.Test.Ecto.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Pow.Test.Ecto.Repo, :manual)

{:ok, _pid} = Pow.Test.Phoenix.Endpoint.start_link()

for extension <- [PowEmailConfirmation, PowPersistentSession, PowResetPassword] do
  endpoint_module = Module.concat([extension, TestWeb.Phoenix.Endpoint])
  {:ok, _pid} = endpoint_module.start_link()
end

Mix.shell(Mix.Shell.Process)
Logger.configure(level: :warn)

ExUnit.start()

# Ensure that symlink to custom ecto priv directory exists
source = Pow.Test.Ecto.Repo.config()[:priv]
target = Application.app_dir(:pow, source)
File.rm_rf(target)
File.mkdir_p(target)
File.rmdir(target)
:ok = :file.make_symlink(Path.expand(source), target)

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

Application.put_env(:mnesia, :dir, 'tmp/mnesia')
Application.ensure_all_started(:mnesia)

Logger.configure(level: :warn)

:ok = Supervisor.terminate_child(Pow.Supervisor, Pow.Store.Backend.EtsCache)

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

for extension <- Application.get_env(:pow, :extension_test_modules) do
  endpoint_module = Module.concat([extension, TestWeb.Phoenix.Endpoint])

  Application.put_env(:pow, endpoint_module,
    render_errors: [view: Pow.Test.Phoenix.ErrorView, accepts: ~w(html json)],
    secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2))

  {:ok, _pid} = endpoint_module.start_link()
end

# Make sure we can run distribution tests
System.cmd("epmd", ["-daemon"])

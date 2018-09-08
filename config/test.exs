use Mix.Config

config :pow, Pow.Test.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [view: Pow.Test.Phoenix.ErrorView, accepts: ~w(html json)]

config :pow, Pow.Test.Ecto.Repo,
  database: "pow_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support/ecto/priv"

config :mnesia, dir: 'tmp/mnesia'

config :pow, Pow.Ecto.Schema.Password, iterations: 1

for extension <- [PowEmailConfirmation, PowResetPassword, PowPersistentSession] do
  context_module = Module.concat([extension, Test])
  web_module = Module.concat([extension, TestWeb])

  config context_module, Module.concat([web_module, Phoenix.Endpoint]),
    render_errors: [view: Module.concat([web_module, Phoenix.ErrorView]), accepts: ~w(html json)],
    secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2)

  config context_module, :pow,
    user: Module.concat([context_module, Users.User]),
    repo: Module.concat([context_module, RepoMock]),
    cache_store_backend: Pow.Test.EtsCacheMock,
    mailer_backend: Pow.Test.Phoenix.MailerMock,
    messages_backend: Module.concat([web_module, Phoenix.Messages]),
    extensions: [extension],
    controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks
end

config :phoenix, :json_library, Jason

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
  web_module = Module.concat([extension, TestWeb])

  config :pow, Module.concat([web_module, Phoenix.Endpoint]),
    render_errors: [view: Module.concat([web_module, Phoenix.ErrorView]), accepts: ~w(html json)],
    secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2)
end

config :phoenix, :json_library, Jason

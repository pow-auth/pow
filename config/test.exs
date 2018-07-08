use Mix.Config

config :authex, Authex.Test.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [view: Authex.Test.Phoenix.ErrorView, accepts: ~w(html json)]

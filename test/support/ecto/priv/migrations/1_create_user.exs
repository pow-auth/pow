require Authex.Ecto.Schema.Migration

Authex.Test.Ecto
|> Authex.Ecto.Schema.Migration.gen()
|> Code.eval_string()

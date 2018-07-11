require Authex.Ecto.UserSchema

Authex.Test.Ecto
|> Authex.Ecto.UserSchema.migration_file()
|> Code.eval_string()

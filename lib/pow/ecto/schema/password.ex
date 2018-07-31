defmodule Pow.Ecto.Schema.Password do
  @moduledoc """
  Simple wrapper for password hash and verification.
  """
  @spec pbkdf2_hash(binary()) :: binary()
  def pbkdf2_hash(password), do: Comeonin.Pbkdf2.hashpwsalt(password)

  @spec pbkdf2_verify(binary(), binary()) :: boolean()
  def pbkdf2_verify(password, hash), do: Comeonin.Pbkdf2.checkpw(password, hash)
end

defmodule Pow.Ecto.Schema.Password do
  @moduledoc """
  Simple wrapper for password hash and verification.

  The password hash format is based on https://github.com/riverrun/pbkdf2_elixir

  ## Options
    * `:iterations`  - defaults to 100_000;
    * `:length`      - a length in octets for the derived key. Defaults to 64;
    * `:digest`      - an hmac function to use as the pseudo-random function. Defaults to `:sha512`;
    * `:salt`        - a salt binary to use. Defaults to a randomly generated binary;
    * `:salt_length` - a length for the random salt binary. Defaults to 16;
  """
  alias Pow.Ecto.Schema.Password.Pbkdf2

  @spec pbkdf2_hash(binary(), Keyword.t() | nil) :: binary()
  def pbkdf2_hash(secret, opts \\ nil) do
    opts        = opts || Application.get_env(:pow, __MODULE__, [])
    iterations  = Keyword.get(opts, :iterations, 100_000)
    length      = Keyword.get(opts, :length, 64)
    digest      = Keyword.get(opts, :digest, :sha512)
    salt_length = Keyword.get(opts, :salt_length, 16)
    salt        = Keyword.get(opts, :salt, :crypto.strong_rand_bytes(salt_length))
    hash        = Pbkdf2.generate(secret, salt, iterations, length, digest)

    encode(digest, iterations, salt, hash)
  end

  @spec pbkdf2_verify(binary(), binary(), Keyword.t()) :: boolean()
  def pbkdf2_verify(secret, secret_hash, opts \\ []) do
    secret_hash
    |> decode()
    |> verify(secret, opts)
  end

  defp encode(digest, iterations, salt, hash) do
    salt = Base.encode64(salt)
    hash = Base.encode64(hash)

    "$pbkdf2-#{digest}$#{iterations}$#{salt}$#{hash}"
  end

  defp decode(hash) do
    case String.split(hash, "$", trim: true) do
      ["pbkdf2-" <> digest, iterations, salt, hash] ->
        {:ok, salt} = Base.decode64(salt)
        {:ok, hash} = Base.decode64(hash)
        digest      = String.to_existing_atom(digest)
        iterations  = String.to_integer(iterations)

        [digest, iterations, salt, hash]

      _ ->
        raise_not_valid_password_hash()
    end
  end

  defp verify([digest, iterations, salt, hash], secret, opts) do
    length      = Keyword.get(opts, :length, 64)
    secret_hash = Pbkdf2.generate(secret, salt, iterations, length, digest)

    Pbkdf2.compare(hash, secret_hash)
  end

  defp raise_not_valid_password_hash do
    raise ArgumentError, "not a valid encoded password hash"
  end
end

defmodule Pow.Plug.MessageVerifier do
  @moduledoc """
  This module can sign and verify messages.

  Based on `Phoenix.Token`.
  """
  alias Plug.{Conn, Crypto.KeyGenerator, Crypto.MessageVerifier}

  @callback sign(Conn.t(), binary(), binary(), keyword()) :: binary()
  @callback verify(Conn.t(), binary(), binary(), keyword()) :: {:ok, binary()} | :error

  @doc """
  Signs a message.

  `Plug.Crypto.MessageVerifier.sign/2` is used. The secret is derived from the
  `salt` and `conn.secret_key_base` using
  `Plug.Crypto.KeyGenerator.generate/3`. If `:key_generator_opts` is set in the
  config, this will be passed on to `Plug.Crypto.KeyGenerator`.
  """
  @spec sign(Conn.t(), binary(), binary(), keyword()) :: binary()
  def sign(conn, salt, message, config) do
    secret = derive(conn, salt, key_opts(config))

    MessageVerifier.sign(message, secret)
  end

  @doc """
  Verifies a message.

  `Plug.Crypto.MessageVerifier.sign/2` is used. The secret is derived from the
  `salt` and `conn.secret_key_base` using
  `Plug.Crypto.KeyGenerator.generate/3`. If `:key_generator_opts` is set in the
  config, this will be passed on to `Plug.Crypto.KeyGenerator`.
  """
  @spec verify(Conn.t(), binary(), binary(), keyword()) :: {:ok, binary()} | :error
  def verify(conn, salt, message, config) do
    secret = derive(conn, salt, key_opts(config))

    MessageVerifier.verify(message, secret)
  end

  defp derive(conn, key, key_opts) do
    conn.secret_key_base
    |> validate_secret_key_base()
    |> KeyGenerator.generate(key, key_opts)
  end

  defp validate_secret_key_base(nil),
    do: raise ArgumentError, "No conn.secret_key_base set"
  defp validate_secret_key_base(secret_key_base) when byte_size(secret_key_base) < 64,
    do: raise ArgumentError, "conn.secret_key_base has to be at least 64 bytes"
  defp validate_secret_key_base(secret_key_base), do: secret_key_base

  defp key_opts(config), do: Keyword.get(config, :key_generator_opts, [])
end

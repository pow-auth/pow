defmodule Pow.Ecto.Schema.Password.Pbkdf2 do
  @moduledoc """
  The Pbkdf2 hash generation code is pulled from
  [Plug.Crypto.KeyGenerator](https://github.com/elixir-plug/plug/blob/v1.6.1/lib/plug/crypto/key_generator.ex#L1)
  and is under Apache 2 license.
  """
  use Bitwise

  @doc """
  Compares the two binaries in constant-time to avoid timing attacks.
  """
  @spec compare(binary(), binary()) :: boolean()
  def compare(left, right) when byte_size(left) == byte_size(right) do
    compare(left, right, 0) == 0
  end
  def compare(_hash, _secret_hash), do: false

  defp compare(<<x, left::binary>>, <<y, right::binary>>, acc) do
    xorred = x ^^^ y
    compare(left, right, acc ||| xorred)
  end
  defp compare(<<>>, <<>>, acc) do
    acc
  end

  @max_length bsl(1, 32) - 1

  @doc """
  Returns a derived key suitable for use.
  """
  @spec generate(binary(), binary(), integer(), integer(), atom()) :: binary()
  def generate(secret, salt, iterations, length, digest) do
    if length > @max_length do
      raise ArgumentError, "length must be less than or equal to #{@max_length}"
    else
      generate(mac_fun(digest, secret), salt, iterations, length, 1, [], 0)
    end
  end

  defp generate(_fun, _salt, _iterations, max_length, _block_index, acc, length)
       when length >= max_length do
    acc
    |> IO.iodata_to_binary()
    |> binary_part(0, max_length)
  end

  defp generate(fun, salt, iterations, max_length, block_index, acc, length) do
    initial = fun.(<<salt::binary, block_index::integer-size(32)>>)
    block = iterate(fun, iterations - 1, initial, initial)

    generate(
      fun,
      salt,
      iterations,
      max_length,
      block_index + 1,
      [acc | block],
      byte_size(block) + length
    )
  end

  defp iterate(_fun, 0, _prev, acc), do: acc

  defp iterate(fun, iteration, prev, acc) do
    next = fun.(prev)
    iterate(fun, iteration - 1, next, :crypto.exor(next, acc))
  end

  defp mac_fun(digest, secret) do
    &:crypto.hmac(digest, secret, &1)
  end
end

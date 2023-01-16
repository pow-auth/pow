defmodule Pow.Ecto.Schema.Password.Pbkdf2 do
  @moduledoc """
  The Pbkdf2 hash generation code is pulled from
  [Plug.Crypto.KeyGenerator](https://github.com/elixir-plug/plug_crypto/blob/v1.2.1/lib/plug/crypto/key_generator.ex)
  and is under Apache 2 license.
  """
  import Bitwise

  @doc """
  Compares the two binaries in constant-time to avoid timing attacks.
  """
  @spec compare(binary(), binary()) :: boolean()
  def compare(left, right) when is_binary(left) and is_binary(right) do
    byte_size(left) == byte_size(right) and compare(left, right, 0)
  end

  defp compare(<<x, left::binary>>, <<y, right::binary>>, acc) do
    xorred = bxor(x, y)
    compare(left, right, acc ||| xorred)
  end

  defp compare(<<>>, <<>>, acc) do
    acc === 0
  end

  @max_length bsl(1, 32) - 1

  @doc """
  Returns a derived key suitable for use.
  """
  @spec generate(binary(), binary(), integer(), integer(), atom()) :: binary()
  def generate(secret, salt, iterations, length, digest) do
    cond do
      not is_integer(iterations) or iterations < 1 ->
        raise ArgumentError, "iterations must be an integer >= 1"

      length > @max_length ->
        raise ArgumentError, "length must be less than or equal to #{@max_length}"

      true ->
        generate(mac_fun(digest, secret), salt, iterations, length, 1, [], 0)
    end
  rescue
    e ->
      stacktrace =
        case __STACKTRACE__ do
          [{mod, fun, [_ | _] = args, info} | rest] ->
            [{mod, fun, length(args), info} | rest]

          stacktrace ->
            stacktrace
        end

      reraise e, stacktrace
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
    length = byte_size(block) + length

    generate(
      fun,
      salt,
      iterations,
      max_length,
      block_index + 1,
      [acc | block],
      length
    )
  end

  defp iterate(_fun, 0, _prev, acc), do: acc

  defp iterate(fun, iteration, prev, acc) do
    next = fun.(prev)
    iterate(fun, iteration - 1, next, :crypto.exor(next, acc))
  end

  # TODO: Remove when OTP 22.1 is required
  if Code.ensure_loaded?(:crypto) and function_exported?(:crypto, :mac, 4) do
    defp mac_fun(digest, secret), do: &:crypto.mac(:hmac, digest, secret, &1)
  else
    defp mac_fun(digest, secret), do: &:crypto.hmac(digest, secret, &1)
  end
end

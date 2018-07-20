defmodule Pow.Test.ConnHelpers do
  @moduledoc false
  alias Plug.{Conn, Test}

  @spec conn(String.Chars.t(), binary(), Test.params()) :: Conn.t()
  def conn(method, path, params_or_body \\ nil) do
    Test.conn(method, path, params_or_body)
  end

  @spec with_session(Conn.t(), Map.t()) :: Conn.t()
  def with_session(conn, opts \\ %{}) do
    Test.init_test_session(conn, opts)
  end

  @spec put_session(Conn.t(), String.t() | atom(), any()) :: Conn.t()
  def put_session(conn, key, value) do
    Conn.put_session(conn, key, value)
  end
end

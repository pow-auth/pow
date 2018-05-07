defmodule Authex.Test.ConnHelpers do
  alias Plug.{Conn, Session, Test}

  @default_opts [
    store: :cookie,
    key: "foobar",
    encryption_salt: "encrypted cookie salt",
    signing_salt: "signing salt",
    log: false
  ]

  @secret String.duplicate("abcdef0123456789", 8)
  @encrypted_opts Session.init(@default_opts)

  @spec conn(String.Chars.t(), binary(), Test.params()) :: Conn.t()
  def conn(method, path, params_or_body \\ nil) do
    Test.conn(method, path, params_or_body)
  end

  @spec with_encrypted_session(Conn.t()) :: Conn.t()
  def with_encrypted_session(conn) do
    conn
    |> Map.put(:secret_key_base, @secret)
    |> Session.call(@encrypted_opts)
    |> Conn.fetch_session()
  end

  @spec put_session(Conn.t(), String.t() | atom(), any()) :: Conn.t()
  def put_session(conn, key, value) do
    Conn.put_session(conn, key, value)
  end
end

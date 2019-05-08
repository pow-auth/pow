defmodule Pow.Test.ConnHelpers do
  @moduledoc false
  alias Plug.{Conn, ProcessStore, Session, Test}

  @spec conn(String.Chars.t(), binary(), Test.params()) :: Conn.t()
  def conn(method, path, params_or_body \\ nil) do
    Test.conn(method, path, params_or_body)
  end

  @spec init_session(Conn.t()) :: Conn.t()
  def init_session(conn) do
    opts = Session.init(store: ProcessStore, key: "foobar")

    Session.call(conn, opts)
  end
end

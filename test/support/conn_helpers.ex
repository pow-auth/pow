defmodule Plug.ProcessStore do
  @moduledoc false
  @behaviour Plug.Session.Store

  def init(_opts) do
    nil
  end

  def get(_conn, sid, nil) do
    {sid, Process.get({:session, sid}) || %{}}
  end

  def delete(_conn, sid, nil) do
    Process.delete({:session, sid})
    :ok
  end

  def put(conn, nil, data, nil) do
    sid = Base.encode64(:crypto.strong_rand_bytes(96))
    put(conn, sid, data, nil)
  end

  def put(_conn, sid, data, nil) do
    Process.put({:session, sid}, data)
    sid
  end
end

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

defmodule Pow.Test.Phoenix.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Pow.Test.EtsCacheMock
  alias Pow.Test.Phoenix.{ControllerAssertions, Endpoint, Router}

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest, except: [get_flash: 2]
      import unquote(__MODULE__), only: [get_flash: 2]
      import ControllerAssertions

      alias Router.Helpers, as: Routes

      @endpoint Endpoint
    end
  end

  setup do
    EtsCacheMock.init()

    {:ok, conn: Phoenix.ConnTest.build_conn(), ets: EtsCacheMock}
  end

  # TODO: Remove when Phoenix 1.7 is required
  if Code.ensure_loaded?(Phoenix.Flash) do
    def get_flash(conn, key), do: Phoenix.Flash.get(conn.assigns.flash, key)
  else
    defdelegate get_flash(conn, key), to: Phoenix.Controller
  end
end

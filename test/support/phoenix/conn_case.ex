defmodule Pow.Test.Phoenix.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Pow.Test.EtsCacheMock
  alias Pow.Test.Phoenix.{ControllerAssertions, Endpoint, Router}

  using do
    quote do
      use Phoenix.ConnTest
      import ControllerAssertions

      alias Router.Helpers, as: Routes

      @endpoint Endpoint
    end
  end

  setup _tags do
    EtsCacheMock.init()

    {:ok, conn: Phoenix.ConnTest.build_conn(), ets: EtsCacheMock}
  end
end

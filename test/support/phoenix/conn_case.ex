defmodule Authex.Test.Phoenix.ConnCase do
  use ExUnit.CaseTemplate
  alias Authex.Test.{EtsCacheMock,
                     Phoenix.ControllerAssertions,
                     Phoenix.Endpoint,
                     Phoenix.Router}

  using do
    quote do
      use Phoenix.ConnTest
      import ControllerAssertions

      alias Router.Helpers, as: Routes

      @endpoint Endpoint
    end
  end

  setup_all _opts do
    {:ok, _pid} = Endpoint.start_link()

    :ok
  end

  setup _tags do
    EtsCacheMock.init()
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

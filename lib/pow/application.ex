defmodule Pow.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Pow.Store.Backend.EtsCache, [[]])
    ]
    opts = [
      strategy: :one_for_one,
      name: Pow.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end

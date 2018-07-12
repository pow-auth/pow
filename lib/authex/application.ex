defmodule Authex.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Authex.Store.EtsCache, [[]])
    ]
    opts = [
      strategy: :one_for_one,
      name: Authex.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end

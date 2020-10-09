defmodule Pow.Application do
  @moduledoc false
  use Application

  @doc """
  Starts the Pow application.

  The EtsCache will be started by default.
  """
  def start(_type, _args) do
    children = [
      Pow.Store.Backend.EtsCache
    ]
    opts = [
      strategy: :one_for_one,
      name: Pow.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end

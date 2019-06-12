# Distributed mnesia cache backend

Pow makes it easy to share cache data, such as the credentials cache, by using the Mnesia cache. There are many ways to handle multi-node Mnesia setup. We'll go through a simple setup that you will be able to expand on as needed.

## Naive cluster setup

First follow [the cache store example in the README.md](../README.md#cache-store).

Now update your `application.ex` module to initiate the Mnesia cluster:

```elixir
defmodule MyApp.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    init_mnesia_cluster(node())

    children = [
      MyApp.Repo,
      MyApp.Endpoint,
      {Pow.Store.Backend.MnesiaCache, nodes: Node.list()}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ...

  defp init_mnesia_cluster(node) do
    connect_nodes()

    :mnesia.start()
    :mnesia.change_config(:extra_db_nodes, Node.list())
    :mnesia.change_table_copy_type(:schema, node, :disc_copies)
    :mnesia.add_table_copy(Pow.Store.Backend.MnesiaCache, node, :disc_copies)
  end

  defp connect_nodes(), do: Enum.each(nodes(), &Node.connect/1)

  defp nodes() do
    {:ok, hostname} = :inet.gethostname()

    for sname <- ["a", "b"], do: :"#{sname}@#{hostname}"
  end
end
```

As you can see, we've replaced `nodes: [node()]`, with `node: Node.list()`, since we'll use all connected nodes to share data with. The private `init_mnesia_cluster/1` method does all the work for you, first attempting to connect to other nodes, and then copy over the data from the cluster (if possible).

The assumption here is that you have two hardcoded nodes, called `a` and `b` (see the private `nodes/0` method) that will be started.

To test this out locally you can update `config/dev.exs` to use `PORT` environment variable like `config/prod.exs`, and then start both nodes with `PORT=4000 iex --sname a -S mix phx.server` and `PORT=4001 iex --sname b -S mix phx.server`.

This example may be useful in blue-green deployment, or similar setup where you spin up a few nodes on a single machine.

## Self discovery

The above example only handles hard coded nodes. You may wish to handle nodes dynamically. For this [`libcluster`](https://github.com/bitwalker/libcluster) may be useful.

## Brain-split

If you run nodes over several machines, [brain-split](https://en.wikipedia.org/wiki/Split-brain_(computing)) may occur. With Pow this isn't a huge deal since all data in the cache is ephemeral, and worst case would be that the user has to sign in again.

Because of this, to recover from brain-split you could just rely on a single node and override the data in the other nodes. However, you may also be able to merge the data during recovery using [`unsplit`](https://github.com/uwiger/unsplit).

defmodule Pow.Store.Backend.Base do
  @moduledoc """
  Used to set up API for key-value cache store.

  [Erlang match specification](https://erlang.org/doc/apps/erts/match_spec.html)
  format is used for the second argument `all/2` callback. The second argument
  is only for the key match, and will look like
  `[:namespace_1, :namespace_2, :_]` or `[:namespace_1, :_, :namespace_2]`.

  ## Usage

  This is an example using [Cachex](https://hex.pm/packages/cachex):

      defmodule MyAppWeb.Pow.CachexCache do
        @behaviour Pow.Store.Backend.Base

        alias Pow.Config

        @cachex_tab __MODULE__

        @impl true
        def put(config, record_or_records) do
          records =
            record_or_records
            |> List.wrap()
            |> Enum.map(fn {key, value} ->
              {wrap_namespace(config, key), value}
            end)

          {:ok, true} = Cachex.put_many(@cachex_tab, records, ttl: Config.get(config, :ttl))

          :ok
        end

        @impl true
        def delete(config, key) do
          key = wrap_namespace(config, key)

          {:ok, _value} = Cachex.del(@cachex_tab, key)

          :ok
        end

        @impl true
        def get(config, key) do
          key = wrap_namespace(config, key)

          case Cachex.get(@cachex_tab, key) do
            {:ok, nil}   -> :not_found
            {:ok, value} -> value
          end
        end

        @impl true
        def all(config, key_match) do
          query =
            [{
              {:_, wrap_namespace(config, key_match), :"$2", :"$3", :"$4"},
              [Cachex.Query.unexpired_clause()],
              [ :"$_" ]
            }]

          @cachex_tab
          |> Cachex.stream!(query)
          |> Enum.map(fn {_, key, _, _, value} -> {unwrap_namespace(key), value} end)
        end

        defp wrap_namespace(config, key) do
          namespace = Config.get(config, :namespace, "cache")

          [namespace | List.wrap(key)]
        end

        defp unwrap_namespace([_namespace, key]), do: key
        defp unwrap_namespace([_namespace | key]), do: key
      end
  """
  alias Pow.Config

  @type config() :: Config.t()
  @type key() :: [binary() | atom()] | binary()
  @type record() :: {key(), any()}
  @type key_match() :: [atom() | binary()]

  @callback put(config(), record() | [record()]) :: :ok
  @callback delete(config(), key()) :: :ok
  @callback get(config(), key()) :: any() | :not_found
  @callback all(config(), key_match()) :: [record()]
end

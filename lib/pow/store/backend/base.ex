defmodule Pow.Store.Backend.Base do
  @moduledoc """
  Used to set up API for key-value cache store.

  ## Usage

  This is an example using [Cachex](https://hex.pm/packages/cachex):

      defmodule MyApp.CachexCache do
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

          Cachex.put_many(@cachex_tab, records, ttl: Config.get(config, :ttl))
        end

        @impl true
        def delete(config, key) do
          key = wrap_namespace(config, key)

          Cachex.del(@cachex_tab, key)
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
        def all(config, match_spec) do
          query = Cachex.Query.create(match_spec, :key)

          @cachex_tab
          |> Cachex.stream!(query)
          |> Enum.map(fn {key, value} -> {unwrap_namespace(key), value} end)
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

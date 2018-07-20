defmodule Pow.Store.Base do
  @moduledoc """
  Used to set up API for key-value cache store.
  """
  alias Pow.{Config, Store.Backend.EtsCache}

  @callback put(Config.t(), binary(), any()) :: :ok
  @callback delete(Config.t(), binary()) :: :ok
  @callback get(Config.t(), binary()) :: any() | :not_found

  defmacro __using__(defaults) do
    quote do
      @behaviour unquote(__MODULE__)

      @spec put(Config.t(), binary(), any()) :: :ok
      def put(config, key, value) do
        store = store(config)
        config = parse_config(config)

        store.put(config, key, value)
      end

      @spec delete(Config.t(), binary()) :: :ok
      def delete(config, key) do
        store = store(config)
        config = parse_config(config)

        store.delete(config, key)
      end

      @spec get(Config.t(), binary()) :: any() | :not_found
      def get(config, key) do
        store = store(config)
        config = parse_config(config)

        store.get(config, key)
      end

      defp parse_config(config) do
        [
          ttl: Config.get(config, :ttl, unquote(defaults[:ttl])),
          namespace: Config.get(config, :namespace, unquote(defaults[:namespace]))
        ]
      end

      defp store(config) do
        Config.get(config, :backend, EtsCache)
      end
    end
  end
end

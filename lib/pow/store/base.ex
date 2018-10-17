defmodule Pow.Store.Base do
  @moduledoc """
  Used to set up API for key-value cache store.

  ## Usage

      defmodule MyApp.CredentialsStore do
        use Pow.Store.Base,
          ttl: :timer.minutes(30),
          namespace: "credentials"
      end
  """
  alias Pow.{Config, Store.Backend.EtsCache}

  @callback put(Config.t(), binary(), any()) :: :ok
  @callback delete(Config.t(), binary()) :: :ok
  @callback get(Config.t(), binary()) :: any() | :not_found
  @callback keys(Config.t()) :: [any()]

  @doc false
  defmacro __using__(defaults) do
    quote do
      @behaviour unquote(__MODULE__)

      @spec put(Config.t(), binary(), any()) :: :ok
      def put(config, key, value),
        do: unquote(__MODULE__).put(config, backend_config(config), key, value)

      @spec delete(Config.t(), binary()) :: :ok
      def delete(config, key),
        do: unquote(__MODULE__).delete(config, backend_config(config), key)

      @spec get(Config.t(), binary()) :: any() | :not_found
      def get(config, key),
        do: unquote(__MODULE__).get(config, backend_config(config), key)

      @spec keys(Config.t()) :: [any()]
      def keys(config),
        do: unquote(__MODULE__).keys(config, backend_config(config))

      defp backend_config(config) do
        [
          ttl: Config.get(config, :ttl, unquote(defaults[:ttl])),
          namespace: Config.get(config, :namespace, unquote(defaults[:namespace]))
        ]
      end

      defoverridable unquote(__MODULE__)
    end
  end

  @doc false
  @spec put(Config.t(), Config.t(), binary(), any()) :: :ok
  def put(config, backend_config, key, value) do
    store(config).put(backend_config, key, value)
  end

  @doc false
  @spec delete(Config.t(), Config.t(), binary()) :: :ok
  def delete(config, backend_config, key) do
    store(config).delete(backend_config, key)
  end

  @doc false
  @spec get(Config.t(), Config.t(), binary()) :: any() | :not_found
  def get(config, backend_config, key) do
    store(config).get(backend_config, key)
  end

  @doc false
  @spec keys(Config.t(), Config.t()) :: [any()]
  def keys(config, backend_config) do
    store(config).keys(backend_config)
  end

  defp store(config) do
    Config.get(config, :backend, EtsCache)
  end
end

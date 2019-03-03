defmodule Pow.Store.Base do
  @moduledoc """
  Used to set up API for key-value stores.

  ## Usage

      defmodule MyApp.CredentialsStore do
        use Pow.Store.Base,
          ttl: :timer.minutes(30),
          namespace: "credentials"

        @impl true
        def put(config, key, value) do
          Pow.Store.Base.put(config, backend_config(config), {key, value})
        end
      end
  """
  alias Pow.Config
  alias Pow.Store.Backend.{EtsCache, Base}

  @type key :: Base.key()
  @type record :: Base.record()
  @type key_match :: Base.key_match()

  @callback put(Config.t(), key(), any()) :: :ok
  @callback delete(Config.t(), key()) :: :ok
  @callback get(Config.t(), key()) :: any() | :not_found
  @callback all(Config.t(), key_match()) :: [record()]

  @doc false
  defmacro __using__(defaults) do
    quote do
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def put(config, key, value) do
        unquote(__MODULE__).put(config, backend_config(config), {key, value})
      end

      @impl unquote(__MODULE__)
      def delete(config, key) do
        unquote(__MODULE__).delete(config, backend_config(config), key)
      end

      @impl unquote(__MODULE__)
      def get(config, key) do
        unquote(__MODULE__).get(config, backend_config(config), key)
      end

      @impl unquote(__MODULE__)
      def all(config, key_match) do
        unquote(__MODULE__).all(config, backend_config(config), key_match)
      end

      @spec backend_config(Config.t()) :: Config.t()
      def backend_config(config) do
        [
          ttl: Config.get(config, :ttl, unquote(defaults[:ttl])),
          namespace: Config.get(config, :namespace, unquote(defaults[:namespace]))
        ]
      end

      defoverridable unquote(__MODULE__)
    end
  end

  @spec put(Config.t(), Config.t(), record() | [record()]) :: :ok
  def put(config, backend_config, record_or_records) do
    store(config).put(backend_config, record_or_records)
  end

  @doc false
  @spec delete(Config.t(), Config.t(), key()) :: :ok
  def delete(config, backend_config, key) do
    store(config).delete(backend_config, key)
  end

  @doc false
  @spec get(Config.t(), Config.t(), key()) :: any() | :not_found
  def get(config, backend_config, key) do
    store(config).get(backend_config, key)
  end

  @doc false
  @spec all(Config.t(), Config.t(), key_match()) :: [record()]
  def all(config, backend_config, key_match) do
    store(config).all(backend_config, key_match)
  end

  defp store(config) do
    Config.get(config, :backend, EtsCache)
  end
end

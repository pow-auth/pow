defmodule Pow.Store.Base do
  @moduledoc """
  Used to set up API for key-value stores.

  ## Usage

      defmodule MyApp.CredentialsStore do
        use Pow.Store.Base,
          ttl: :timer.minutes(30),
          namespace: "credentials"

        @impl true
        def put(config, backend_config, key, value) do
          Pow.Store.Base.put(config, backend_config, {key, value})
        end
      end
  """
  alias Pow.Config
  alias Pow.Store.Backend.{EtsCache, MnesiaCache, Base}

  @type key :: Base.key()
  @type record :: Base.record()
  @type key_match :: Base.key_match()

  @callback put(Config.t(), Config.t(), key(), any()) :: :ok
  @callback delete(Config.t(), Config.t(), key()) :: :ok
  @callback get(Config.t(), Config.t(), key()) :: any() | :not_found
  @callback all(Config.t(), Config.t(), key_match()) :: [record()]

  @doc false
  defmacro __using__(defaults) do
    quote do
      @behaviour unquote(__MODULE__)

      @spec put(Config.t(), unquote(__MODULE__).key(), any()) :: :ok
      def put(config, key, value),
        do: put(config, backend_config(config), key, value)

      @spec delete(Config.t(), unquote(__MODULE__).key()) :: :ok
      def delete(config, key),
        do: delete(config, backend_config(config), key)

      @spec get(Config.t(), unquote(__MODULE__).key()) :: any() | :not_found
      def get(config, key),
        do: get(config, backend_config(config), key)

      @spec all(Config.t(), unquote(__MODULE__).key_match()) :: [unquote(__MODULE__).record()]
      def all(config, key_match),
        do: all(config, backend_config(config), key_match)

      defp backend_config(config) do
        [
          ttl: Config.get(config, :ttl, unquote(defaults[:ttl])),
          namespace: Config.get(config, :namespace, unquote(defaults[:namespace]))
        ]
      end

      @impl unquote(__MODULE__)
      def put(config, backend_config, key, value), do: unquote(__MODULE__).put(config, backend_config, {key, value})

      defdelegate delete(config, backend_config, key), to: unquote(__MODULE__)
      defdelegate get(config, backend_config, key), to: unquote(__MODULE__)
      defdelegate all(config, backend_config, key_match), to: unquote(__MODULE__)

      defoverridable unquote(__MODULE__)

      # TODO: Remove by 1.1.0
      defoverridable put: 3, delete: 2, get: 2, all: 2
    end
  end

  @spec put(Config.t(), Config.t(), record() | [record()]) :: :ok
  def put(config, backend_config, record_or_records) do
    # TODO: Update by 1.1.0
    backwards_compatible_call(store(config), :put, [backend_config, record_or_records])
  end

  @doc false
  @spec delete(Config.t(), Config.t(), key()) :: :ok
  def delete(config, backend_config, key) do
    # TODO: Update by 1.1.0
    backwards_compatible_call(store(config), :delete, [backend_config, key])
  end

  @doc false
  @spec get(Config.t(), Config.t(), key()) :: any() | :not_found
  def get(config, backend_config, key) do
    # TODO: Update by 1.1.0
    backwards_compatible_call(store(config), :get, [backend_config, key])
  end

  @doc false
  @spec all(Config.t(), Config.t(), key_match()) :: [record()]
  def all(config, backend_config, key_match) do
    # TODO: Update by 1.1.0
    backwards_compatible_call(store(config), :all, [backend_config, key_match])
  end

  defp store(config) do
    Config.get(config, :backend, EtsCache)
  end

  # TODO: Remove by 1.1.0
  defp backwards_compatible_call(store, method, args) do
    store
    |> has_binary_keys?()
    |> case do
      false ->
        apply(store, method, args)

      true ->
        IO.warn("binary key for backend stores is depecated, update `#{store}` to accept erlang terms instead")

        case method do
          :put    -> binary_key_put(store, args)
          :get    -> binary_key_get(store, args)
          :delete -> binary_key_delete(store, args)
          :all    -> binary_key_all(store, args)
        end
    end
  end

  # TODO: Remove by 1.1.0
  defp has_binary_keys?(store) when store in [EtsCache, MnesiaCache], do: false
  defp has_binary_keys?(store), do: not function_exported?(store, :all, 2)

  # TODO: Remove by 1.1.0
  defp binary_key_put(store, [backend_config, record_or_records]) do
    record_or_records
    |> List.wrap()
    |> Enum.each(fn {key, value} ->
      key = binary_key(key)

      store.put(backend_config, key, value)
    end)
  end

  # TODO: Remove by 1.1.0
  defp binary_key_get(store, [backend_config, key]) do
    key = binary_key(key)

    store.get(backend_config, key)
  end

  # TODO: Remove by 1.1.0
  defp binary_key_delete(store, [backend_config, key]) do
    key = binary_key(key)

    store.delete(backend_config, key)
  end

  # TODO: Remove by 1.1.0
  defp binary_key_all(store, [backend_config, match_spec]) do
    match_spec = :ets.match_spec_compile([{match_spec, [], [:"$_"]}])

    backend_config
    |> store.keys()
    |> Enum.map(&:erlang.binary_to_term/1)
    |> :ets.match_spec_run(match_spec)
    |> Enum.map(&{&1, binary_key_get(store, [backend_config, &1])})
  end

  # TODO: Remove by 1.1.0
  defp binary_key(key) do
    key
    |> List.wrap()
    |> :erlang.term_to_binary()
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `put/3` instead"
  def put(config, backend_config, key, value) do
    put(config, backend_config, {key, value})
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `all/2` instead"
  def keys(config, backend_config) do
    store(config).keys(backend_config)
  end
end

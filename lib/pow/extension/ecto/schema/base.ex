defmodule Pow.Extension.Ecto.Schema.Base do
  @moduledoc """
  Used for extensions to extend user schemas.

  The macro will add fallback functions to the module, that can be overridden.

  ## Usage

      defmodule MyPowExtension.Ecto.Schema do
        use Pow.Extension.Ecto.Schema.Base

        @impl true
        def attrs(_config) do
          [{:custom_field, :string}]
        end

        @impl true
        def changeset(changeset, _config) do
          Ecto.Changeset.validate_required(changeset, [:custom_field])
        end
      end
  """
  alias Ecto.Changeset
  alias Pow.Config

  @callback validate!(Config.t(), atom()) :: :ok
  @callback attrs(Config.t()) :: [tuple()]
  @callback assocs(Config.t()) :: [tuple()]
  @callback indexes(Config.t()) :: [tuple()]
  @callback changeset(Changeset.t(), map(), Config.t()) :: Changeset.t()
  @macrocallback __using__(Config.t()) :: Macro.t()
  @optional_callbacks __using__: 1

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      @doc false
      def validate!(_config, _module), do: :ok

      @doc false
      def attrs(_config), do: []

      @doc false
      def assocs(_config), do: []

      @doc false
      def indexes(_config), do: []

      @doc false
      def changeset(changeset, _attrs, _config), do: changeset

      defoverridable unquote(__MODULE__)
    end
  end
end

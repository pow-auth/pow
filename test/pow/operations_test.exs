defmodule Pow.OperationsTest do
  use ExUnit.Case
  doctest Pow.Operations

  alias Pow.Operations

  defmodule PrimaryFieldUser do
    use Ecto.Schema

    schema "users" do
      timestamps()
    end
  end

  defmodule NoPrimaryFieldUser do
    use Ecto.Schema

    @primary_key false
    schema "users" do
      timestamps()
    end
  end

  defmodule CompositePrimaryFieldsUser do
    use Ecto.Schema

    @primary_key false
    schema "users" do
      field :some_id, :integer, primary_key: true
      field :another_id, :integer, primary_key: true

      timestamps()
    end
  end

  defmodule NonEctoUser do
    defstruct [:id]
  end

  @config []

  describe "fetch_primary_key_values/2" do
    test "handles nil primary key value" do
      assert Operations.fetch_primary_key_values(%PrimaryFieldUser{id: nil}, @config) == {:error, "Primary key value for key `:id` in #{inspect PrimaryFieldUser} can't be `nil`"}
      assert Operations.fetch_primary_key_values(%CompositePrimaryFieldsUser{}, @config) == {:error, "Primary key value for key `:some_id` in #{inspect CompositePrimaryFieldsUser} can't be `nil`"}
      assert Operations.fetch_primary_key_values(%NonEctoUser{}, @config) == {:error, "Primary key value for key `:id` in #{inspect NonEctoUser} can't be `nil`"}
    end

    test "requires primary key" do
      assert Operations.fetch_primary_key_values(%NoPrimaryFieldUser{}, @config) == {:error, "No primary keys found for #{inspect NoPrimaryFieldUser}"}
    end

    test "returns keyword list" do
      assert Operations.fetch_primary_key_values(%PrimaryFieldUser{id: 1}, @config) == {:ok, id: 1}
      assert Operations.fetch_primary_key_values(%CompositePrimaryFieldsUser{some_id: 1, another_id: 2}, @config) == {:ok, some_id: 1, another_id: 2}
      assert Operations.fetch_primary_key_values(%NonEctoUser{id: 1}, @config) == {:ok, id: 1}
    end

    test "requires module exists" do
      assert Operations.fetch_primary_key_values(%{__struct__: Invalid}, @config) == {:error, "The module Invalid does not exist"}
    end
  end
end

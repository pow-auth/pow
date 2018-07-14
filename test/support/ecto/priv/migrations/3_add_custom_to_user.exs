defmodule Authex.Test.Ecto.Repo.Migrations.AddCustomToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :custom, :string
    end
  end
end

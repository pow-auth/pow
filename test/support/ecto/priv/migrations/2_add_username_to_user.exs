defmodule Authex.Test.Ecto.Repo.Migrations.AddUsernameToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :string
      modify :email, :string, null: true
    end
    create unique_index(:users, [:username])
  end
end

defmodule Claper.Repo.Migrations.AddLogoPathToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :logo_path, :string
    end
  end
end

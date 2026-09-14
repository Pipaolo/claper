defmodule Claper.Repo.Migrations.AddThemeToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :theme_background, :string
      add :theme_accent, :string
      add :theme_surface, :string
    end
  end
end

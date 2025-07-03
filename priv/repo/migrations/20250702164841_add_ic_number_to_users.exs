defmodule HeadsUp.Repo.Migrations.AddIcNumberToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :ic_number, :string, size: 12
    end

    create index(:users, [:ic_number])
  end
end

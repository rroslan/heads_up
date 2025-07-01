defmodule HeadsUp.Repo.Migrations.CreateSurveyTokens do
  use Ecto.Migration

  def change do
    create table(:survey_tokens) do
      add :ic_number, :string, null: false, size: 12
      add :token, :string, null: false
      add :birth_date, :date
      add :birth_place_code, :string, size: 2
      add :gender, :string, size: 1
      add :age, :integer
      add :used_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :created_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:survey_tokens, [:ic_number])
    create unique_index(:survey_tokens, [:token])
    create index(:survey_tokens, [:expires_at])
    create index(:survey_tokens, [:used_at])
  end
end

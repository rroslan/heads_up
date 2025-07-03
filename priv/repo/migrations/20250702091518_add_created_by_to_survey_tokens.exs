defmodule HeadsUp.Repo.Migrations.AddCreatedByToSurveyTokens do
  use Ecto.Migration

  def change do
    alter table(:survey_tokens) do
      add :created_by_user_id, references(:users, on_delete: :nilify_all)
    end

    create index(:survey_tokens, [:created_by_user_id])
  end
end

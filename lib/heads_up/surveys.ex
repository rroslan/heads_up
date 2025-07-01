defmodule HeadsUp.Surveys do
  @moduledoc """
  The Surveys context.
  """

  import Ecto.Query, warn: false
  alias HeadsUp.Repo

  alias HeadsUp.Surveys.SurveyToken

  @doc """
  Returns the list of survey_tokens.

  ## Examples

      iex> list_survey_tokens()
      [%SurveyToken{}, ...]

  """
  def list_survey_tokens do
    Repo.all(SurveyToken)
  end

  @doc """
  Gets a single survey_token.

  Raises `Ecto.NoResultsError` if the Survey token does not exist.

  ## Examples

      iex> get_survey_token!(123)
      %SurveyToken{}

      iex> get_survey_token!(456)
      ** (Ecto.NoResultsError)

  """
  def get_survey_token!(id), do: Repo.get!(SurveyToken, id)

  @doc """
  Gets a survey token by token string.

  ## Examples

      iex> get_survey_token_by_token("valid_token")
      {:ok, %SurveyToken{}}

      iex> get_survey_token_by_token("invalid_token")
      {:error, :not_found}

  """
  def get_survey_token_by_token(token) do
    case Repo.get_by(SurveyToken, token: token) do
      nil -> {:error, :not_found}
      survey_token -> {:ok, survey_token}
    end
  end

  @doc """
  Gets a survey token by IC number.

  ## Examples

      iex> get_survey_token_by_ic("123456789012")
      {:ok, %SurveyToken{}}

      iex> get_survey_token_by_ic("invalid_ic")
      {:error, :not_found}

  """
  def get_survey_token_by_ic(ic_number) do
    case Repo.get_by(SurveyToken, ic_number: ic_number) do
      nil -> {:error, :not_found}
      survey_token -> {:ok, survey_token}
    end
  end

  @doc """
  Creates a survey_token from Malaysian IC number.

  ## Examples

      iex> create_survey_token_from_ic("501007081234")
      {:ok, %SurveyToken{}}

      iex> create_survey_token_from_ic("invalid")
      {:error, %Ecto.Changeset{}}

  """
  def create_survey_token_from_ic(ic_number) do
    # Check if token already exists for this IC
    case get_survey_token_by_ic(ic_number) do
      {:ok, existing_token} ->
        if SurveyToken.valid?(existing_token) do
          {:ok, existing_token}
        else
          # Delete old invalid token and create new one
          delete_survey_token(existing_token)
          create_new_token_from_ic(ic_number)
        end

      {:error, :not_found} ->
        create_new_token_from_ic(ic_number)
    end
  end

  defp create_new_token_from_ic(ic_number) do
    case SurveyToken.create_from_ic(ic_number) do
      {:ok, changeset} ->
        Repo.insert(changeset)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates a survey_token.

  ## Examples

      iex> update_survey_token(survey_token, %{field: new_value})
      {:ok, %SurveyToken{}}

      iex> update_survey_token(survey_token, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_survey_token(%SurveyToken{} = survey_token, attrs) do
    survey_token
    |> SurveyToken.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a survey_token.

  ## Examples

      iex> delete_survey_token(survey_token)
      {:ok, %SurveyToken{}}

      iex> delete_survey_token(survey_token)
      {:error, %Ecto.Changeset{}}

  """
  def delete_survey_token(%SurveyToken{} = survey_token) do
    Repo.delete(survey_token)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking survey_token changes.

  ## Examples

      iex> change_survey_token(survey_token)
      %Ecto.Changeset{data: %SurveyToken{}}

  """
  def change_survey_token(%SurveyToken{} = survey_token, attrs \\ %{}) do
    SurveyToken.changeset(survey_token, attrs)
  end

  @doc """
  Validates and uses a survey token.

  ## Examples

      iex> use_survey_token("valid_token")
      {:ok, %SurveyToken{}}

      iex> use_survey_token("invalid_token")
      {:error, :invalid_token}

      iex> use_survey_token("expired_token")
      {:error, :expired_token}

  """
  def use_survey_token(token) do
    case get_survey_token_by_token(token) do
      {:ok, survey_token} ->
        cond do
          not SurveyToken.valid?(survey_token) ->
            {:error, :invalid_token}

          true ->
            survey_token
            |> SurveyToken.mark_as_used()
            |> Repo.update()
        end

      {:error, :not_found} ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Validates a survey token without marking it as used.

  ## Examples

      iex> validate_survey_token("valid_token")
      {:ok, %SurveyToken{}}

      iex> validate_survey_token("invalid_token")
      {:error, :invalid_token}

  """
  def validate_survey_token(token) do
    case get_survey_token_by_token(token) do
      {:ok, survey_token} ->
        if SurveyToken.valid?(survey_token) do
          {:ok, survey_token}
        else
          {:error, :invalid_token}
        end

      {:error, :not_found} ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Cleans up expired tokens.
  """
  def cleanup_expired_tokens do
    now = DateTime.utc_now()

    from(t in SurveyToken, where: t.expires_at < ^now)
    |> Repo.delete_all()
  end

  @doc """
  Gets demographic information from IC number for display purposes.

  ## Examples

      iex> get_ic_info("501007081234")
      {:ok, %{age: 74, birth_date: ~D[1950-10-07], gender: "M", birth_place: "08"}}

      iex> get_ic_info("invalid")
      {:error, "Invalid IC format"}
  """
  def get_ic_info(ic_number) do
    SurveyToken.parse_ic(ic_number)
  end
end

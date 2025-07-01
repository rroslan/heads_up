defmodule HeadsUp.Surveys.SurveyToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "survey_tokens" do
    field :ic_number, :string
    field :token, :string
    field :birth_date, :date
    field :birth_place_code, :string
    field :gender, :string
    field :age, :integer
    field :used_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :created_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(survey_token, attrs) do
    survey_token
    |> cast(attrs, [
      :ic_number,
      :token,
      :birth_date,
      :birth_place_code,
      :gender,
      :age,
      :used_at,
      :expires_at,
      :created_at
    ])
    |> validate_required([:ic_number, :token, :expires_at, :created_at])
    |> validate_length(:ic_number, is: 12)
    |> validate_format(:ic_number, ~r/^[0-9]{12}$/, message: "must be exactly 12 digits")
    |> validate_length(:birth_place_code, is: 2)
    |> validate_inclusion(:gender, ["M", "F"])
    |> unique_constraint(:ic_number)
    |> unique_constraint(:token)
  end

  @doc """
  Creates a new survey token from Malaysian IC number.
  Parses the IC to extract birth date, birth place, gender, and age.
  """
  def create_from_ic(ic_number) when is_binary(ic_number) do
    if byte_size(ic_number) == 12 do
      with {:ok, parsed_data} <- parse_ic(ic_number) do
        token = generate_token()
        # 24 hours from now
        expires_at = DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second)
        created_at = DateTime.utc_now()

        attrs =
          Map.merge(parsed_data, %{
            ic_number: ic_number,
            token: token,
            expires_at: expires_at,
            created_at: created_at
          })

        {:ok, %__MODULE__{} |> changeset(attrs)}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "IC number must be exactly 12 digits"}
    end
  end

  def create_from_ic(_), do: {:error, "Invalid IC format"}

  @doc """
  Parses Malaysian IC number to extract demographic information.
  Format: YYMMDD-PB-###G
  - YY: Year (need to determine century)
  - MM: Month
  - DD: Day
  - PB: Place of birth code (2 digits)
  - ###: Sequential number
  - G: Gender (odd = male, even = female)
  """
  def parse_ic(ic_number) when is_binary(ic_number) do
    if byte_size(ic_number) == 12 do
      case Regex.match?(~r/^[0-9]{12}$/, ic_number) do
        false ->
          {:error, "Invalid IC format"}

        true ->
          <<year_str::binary-size(2), month_str::binary-size(2), day_str::binary-size(2),
            place_code::binary-size(2), _seq::binary-size(3),
            gender_digit::binary-size(1)>> = ic_number

          with {:ok, year} <- parse_year(year_str),
               {:ok, month} <- parse_month(month_str),
               {:ok, day} <- parse_day(day_str),
               {:ok, birth_date} <- Date.new(year, month, day),
               age <- calculate_age(birth_date),
               gender <- parse_gender(gender_digit) do
            {:ok,
             %{
               birth_date: birth_date,
               birth_place_code: place_code,
               gender: gender,
               age: age
             }}
          else
            {:error, reason} -> {:error, "Invalid date: #{reason}"}
          end
      end
    else
      {:error, "Invalid IC format"}
    end
  end

  def parse_ic(_), do: {:error, "Invalid IC format"}

  defp parse_year(year_str) do
    year_int = String.to_integer(year_str)
    current_year = Date.utc_today().year
    current_century = div(current_year, 100) * 100
    current_two_digit = rem(current_year, 100)

    # Determine century based on current year
    full_year =
      cond do
        year_int <= current_two_digit -> current_century + year_int
        true -> current_century - 100 + year_int
      end

    {:ok, full_year}
  end

  defp parse_month(month_str) do
    month = String.to_integer(month_str)

    if month >= 1 and month <= 12 do
      {:ok, month}
    else
      {:error, "Invalid month"}
    end
  end

  defp parse_day(day_str) do
    day = String.to_integer(day_str)

    if day >= 1 and day <= 31 do
      {:ok, day}
    else
      {:error, "Invalid day"}
    end
  end

  defp parse_gender(gender_digit) do
    gender_int = String.to_integer(gender_digit)
    if rem(gender_int, 2) == 1, do: "M", else: "F"
  end

  defp calculate_age(birth_date) do
    today = Date.utc_today()
    age = today.year - birth_date.year

    # Adjust age if birthday hasn't occurred this year
    if today.month < birth_date.month or
         (today.month == birth_date.month and today.day < birth_date.day) do
      age - 1
    else
      age
    end
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Checks if token is valid (not used and not expired)
  """
  def valid?(%__MODULE__{used_at: nil, expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :lt
  end

  def valid?(%__MODULE__{used_at: used_at}) when not is_nil(used_at), do: false
  def valid?(_), do: false

  @doc """
  Marks token as used
  """
  def mark_as_used(%__MODULE__{} = token) do
    changeset(token, %{used_at: DateTime.utc_now()})
  end
end

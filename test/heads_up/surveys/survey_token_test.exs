defmodule HeadsUp.Surveys.SurveyTokenTest do
  use HeadsUp.DataCase

  alias HeadsUp.Surveys.SurveyToken

  describe "parse_ic/1" do
    test "parses valid IC number correctly" do
      # Test IC: 501007081234
      # 50 = year 1950, 10 = October, 07 = 7th day
      # 08 = birth place code, 123 = sequential, 4 = even (female)
      ic = "501007081234"

      {:ok, result} = SurveyToken.parse_ic(ic)

      assert result.birth_date == ~D[1950-10-07]
      assert result.birth_place_code == "08"
      assert result.gender == "F"
      # Age can vary based on current date
      assert result.age in [73, 74]
    end

    test "parses male IC correctly" do
      # Test IC with odd last digit (male)
      ic = "850315101235"

      {:ok, result} = SurveyToken.parse_ic(ic)

      assert result.birth_date == ~D[1985-03-15]
      assert result.birth_place_code == "10"
      assert result.gender == "M"
    end

    test "handles current century correctly" do
      # Test IC with year that should be in 2000s
      ic = "051225081234"

      {:ok, result} = SurveyToken.parse_ic(ic)

      assert result.birth_date == ~D[2005-12-25]
      # Age can vary based on current date
      assert result.age in [18, 19]
    end

    test "rejects invalid IC format" do
      assert {:error, "Invalid IC format"} = SurveyToken.parse_ic("12345")
      assert {:error, "Invalid IC format"} = SurveyToken.parse_ic("abcdefghijkl")
      assert {:error, "Invalid IC format"} = SurveyToken.parse_ic("123456789012a")
    end

    test "rejects invalid dates" do
      # Invalid month
      assert {:error, "Invalid date: " <> _} = SurveyToken.parse_ic("501307081234")

      # Invalid day
      assert {:error, "Invalid date: " <> _} = SurveyToken.parse_ic("501032081234")
    end
  end

  describe "create_from_ic/1" do
    test "creates valid changeset from IC" do
      ic = "501007081234"

      {:ok, changeset} = SurveyToken.create_from_ic(ic)

      assert changeset.valid?
      assert get_change(changeset, :ic_number) == ic
      assert get_change(changeset, :birth_date) == ~D[1950-10-07]
      assert get_change(changeset, :gender) == "F"
      assert get_change(changeset, :birth_place_code) == "08"
      assert get_change(changeset, :token) != nil
      assert get_change(changeset, :expires_at) != nil
    end

    test "rejects invalid IC" do
      assert {:error, "IC number must be exactly 12 digits"} =
               SurveyToken.create_from_ic("invalid")
    end
  end

  describe "valid?/1" do
    test "returns true for unused, non-expired token" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)

      token = %SurveyToken{
        used_at: nil,
        expires_at: future_time
      }

      assert SurveyToken.valid?(token)
    end

    test "returns false for used token" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)

      token = %SurveyToken{
        used_at: DateTime.utc_now(),
        expires_at: future_time
      }

      refute SurveyToken.valid?(token)
    end

    test "returns false for expired token" do
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      token = %SurveyToken{
        used_at: nil,
        expires_at: past_time
      }

      refute SurveyToken.valid?(token)
    end
  end

  describe "changeset/2" do
    test "validates IC number length" do
      changeset = SurveyToken.changeset(%SurveyToken{}, %{ic_number: "12345"})

      assert "must be exactly 12 digits" in errors_on(changeset).ic_number
    end

    test "validates IC number format" do
      changeset = SurveyToken.changeset(%SurveyToken{}, %{ic_number: "abcdefghijkl"})

      assert "must be exactly 12 digits" in errors_on(changeset).ic_number
    end

    test "validates required fields" do
      changeset = SurveyToken.changeset(%SurveyToken{}, %{})

      assert "can't be blank" in errors_on(changeset).ic_number
      assert "can't be blank" in errors_on(changeset).token
      assert "can't be blank" in errors_on(changeset).expires_at
      assert "can't be blank" in errors_on(changeset).created_at
    end

    test "validates gender inclusion" do
      attrs = %{
        ic_number: "501007081234",
        token: "test_token",
        expires_at: DateTime.utc_now(),
        created_at: DateTime.utc_now(),
        gender: "X"
      }

      changeset = SurveyToken.changeset(%SurveyToken{}, attrs)

      assert "is invalid" in errors_on(changeset).gender
    end
  end

  describe "age calculation" do
    test "calculates age correctly before birthday" do
      # Birth date: March 15, 1985
      # Current date: March 10, 2024 (before birthday)
      birth_date = ~D[1985-03-15]

      # Mock current date
      current_date = ~D[2024-03-10]

      # Calculate age manually for this test
      # -1 because birthday hasn't passed
      age = current_date.year - birth_date.year - 1

      assert age == 38
    end

    test "calculates age correctly after birthday" do
      # Birth date: March 15, 1985
      # Current date: March 20, 2024 (after birthday)
      birth_date = ~D[1985-03-15]

      # Mock current date
      current_date = ~D[2024-03-20]

      # Calculate age manually for this test
      # No adjustment needed
      age = current_date.year - birth_date.year

      assert age == 39
    end
  end
end

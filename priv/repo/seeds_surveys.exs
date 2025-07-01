# Survey Seeds
alias HeadsUp.Surveys

# Create a sample survey for testing
sample_questions = %{
  "0" => %{
    "text" => "What is your name?",
    "type" => "text",
    "description" => "Please enter your full name",
    "required" => true
  },
  "1" => %{
    "text" => "How would you rate our service?",
    "type" => "radio",
    "description" => "Please select one option",
    "required" => true,
    "options" => ["Excellent", "Good", "Fair", "Poor"]
  },
  "2" => %{
    "text" => "What features would you like to see? (Select all that apply)",
    "type" => "checkbox",
    "description" => "You can select multiple options",
    "required" => false,
    "options" => ["Mobile app", "Email notifications", "Advanced reporting", "Integration with other tools", "Custom themes"]
  },
  "3" => %{
    "text" => "What is your age?",
    "type" => "number",
    "description" => "Please enter your age in years",
    "required" => false,
    "min" => 18,
    "max" => 120
  },
  "4" => %{
    "text" => "What is your email address?",
    "type" => "email",
    "description" => "We'll use this to follow up with you",
    "required" => true
  },
  "5" => %{
    "text" => "Additional comments",
    "type" => "textarea",
    "description" => "Please share any additional feedback or suggestions",
    "required" => false
  }
}

# Create the survey
{:ok, survey} = Surveys.create_survey(%{
  title: "Customer Satisfaction Survey",
  description: "Help us improve our services by sharing your feedback. This survey should take about 5 minutes to complete.",
  active: true,
  questions: sample_questions
})

IO.puts("Created sample survey with token: #{survey.token}")
IO.puts("You can access it at: http://localhost:4000/surveys/#{survey.token}")

# Create another survey for testing
{:ok, product_survey} = Surveys.create_survey(%{
  title: "Product Feedback Survey",
  description: "We'd love to hear your thoughts about our latest product release.",
  active: true,
  questions: %{
    "0" => %{
      "text" => "Which product are you reviewing?",
      "type" => "select",
      "description" => "Please select the product you're providing feedback for",
      "required" => true,
      "options" => ["Product A", "Product B", "Product C", "Product D"]
    },
    "1" => %{
      "text" => "How likely are you to recommend this product to a friend?",
      "type" => "radio",
      "description" => "Scale from 1 (Not likely) to 5 (Very likely)",
      "required" => true,
      "options" => ["1 - Not likely", "2 - Slightly likely", "3 - Moderately likely", "4 - Very likely", "5 - Extremely likely"]
    },
    "2" => %{
      "text" => "What is the main reason for your rating?",
      "type" => "textarea",
      "description" => "Please explain your rating in detail",
      "required" => true
    }
  }
})

IO.puts("Created product survey with token: #{product_survey.token}")
IO.puts("You can access it at: http://localhost:4000/surveys/#{product_survey.token}")

# Create an inactive survey for testing
{:ok, _inactive_survey} = Surveys.create_survey(%{
  title: "Internal Team Survey",
  description: "This survey is currently inactive and won't be accessible to the public.",
  active: false,
  questions: %{
    "0" => %{
      "text" => "This is an inactive survey",
      "type" => "text",
      "required" => false
    }
  }
})

IO.puts("Created inactive survey for testing")
IO.puts("Total surveys created: 3")

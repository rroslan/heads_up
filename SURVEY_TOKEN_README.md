# Malaysian IC Survey Token System

This system generates secure, time-limited tokens for survey access based on Malaysian IC (MyKad) numbers. It parses demographic information from the IC number to create personalized survey experiences.

## Features

- **IC Number Parsing**: Extracts birth date, age, gender, and birth place from Malaysian IC numbers
- **Secure Token Generation**: Creates unique, time-limited tokens for survey access
- **One-time Use**: Each token can only be used once to complete a survey
- **24-hour Expiry**: Tokens automatically expire after 24 hours
- **Demographic Analysis**: Automatically calculates age and extracts demographic data

## How Malaysian IC Numbers Work

Malaysian IC numbers follow the format: `YYMMDD-PB-###G`

- **Digits 1-6 (YYMMDD)**: Birth date
  - YY: Year (automatically determines century)
  - MM: Month (01-12)
  - DD: Day (01-31)
- **Digits 7-8 (PB)**: Place of birth code (state/region identifier)
- **Digits 9-11 (###)**: Sequential registration number
- **Digit 12 (G)**: Gender indicator (odd = male, even = female)

### Example
IC Number: `501007081234`
- `50`: Born in 1950 (system determines century based on current year)
- `10`: October
- `07`: 7th day of the month
- `08`: Birth place code (Perak)
- `123`: Sequential number
- `4`: Even number = Female

**Result**: Female, born October 7, 1950, age 74-75, from Perak

## Usage

### 1. Access the Token Generator
Navigate to `/token` on the application to access the token generation page.

**Authentication Required**: You must be logged in as a registered user to generate tokens. These tokens can then be shared with unregistered participants.

### 2. Enter IC Number
- Enter exactly 12 digits
- No spaces, dashes, or other characters needed
- System will automatically validate and parse the IC

### 3. Generate Token
- System extracts demographic information
- Creates a unique, secure token
- Provides a survey access URL

### 4. Access Survey
- Use the generated URL to access the survey
- Token is valid for 24 hours from generation
- Token can only be used once

**Authentication Required**: No authentication required. Anyone with a valid token link can access and complete the survey.

## API Endpoints

### Token Generation Page
```
GET /token
```
Interactive page for IC input and token generation.

**Requires**: User authentication (any registered user)

### Survey Access
```
GET /survey/:token
```
Access survey using generated token. Token must be valid and unused.

**Requires**: Valid token only (no user authentication needed)

## Technical Implementation

### Database Schema
```sql
CREATE TABLE survey_tokens (
  id SERIAL PRIMARY KEY,
  ic_number VARCHAR(12) NOT NULL UNIQUE,
  token VARCHAR(255) NOT NULL UNIQUE,
  birth_date DATE,
  birth_place_code VARCHAR(2),
  gender VARCHAR(1),
  age INTEGER,
  used_at TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

### Key Functions

#### `HeadsUp.Surveys.create_survey_token_from_ic/1`
Creates a new survey token from a Malaysian IC number.

```elixir
{:ok, token} = HeadsUp.Surveys.create_survey_token_from_ic("501007081234")
```

#### `HeadsUp.Surveys.validate_survey_token/1`
Validates a token without marking it as used.

```elixir
{:ok, token} = HeadsUp.Surveys.validate_survey_token("generated_token_string")
```

#### `HeadsUp.Surveys.use_survey_token/1`
Validates and marks a token as used (for survey completion).

```elixir
{:ok, used_token} = HeadsUp.Surveys.use_survey_token("generated_token_string")
```

## Security Features

1. **Authentication Model**: 
   - Token generation requires user authentication (any registered user)
   - Survey access requires no authentication (token validation only)
2. **Unique Tokens**: Cryptographically secure random tokens
3. **Time-Limited**: 24-hour expiration
4. **One-Time Use**: Tokens become invalid after use
5. **IC Validation**: Strict validation of Malaysian IC format
6. **No Personal Data Storage**: Only necessary demographic data stored

## Error Handling

The system handles various error cases:

- **Authentication Errors**: Unauthorized token generation attempts
- **Invalid IC Format**: Non-12-digit or non-numeric input
- **Invalid Dates**: Impossible dates (e.g., February 30)
- **Expired Tokens**: Tokens past 24-hour expiry
- **Used Tokens**: Previously completed survey tokens
- **Duplicate IC**: Automatic cleanup and regeneration for same IC

## Testing

Run the test suite:

```bash
mix test test/heads_up/surveys/survey_token_test.exs
```

Test cases cover:
- IC number parsing and validation
- Token generation and validation
- Age calculation accuracy
- Error handling scenarios

## Database Management

### Cleanup Expired Tokens
```elixir
HeadsUp.Surveys.cleanup_expired_tokens()
```

### Migration
```bash
mix ecto.migrate
```

## Example IC Numbers for Testing

Valid test IC numbers:
- `501007081234` - Female, born Oct 7, 1950, age ~74
- `850315101235` - Male, born Mar 15, 1985, age ~39
- `051225081234` - Female, born Dec 25, 2005, age ~19

## State/Region Codes (Digits 7-8)

Common Malaysian birth place codes:
- `01-21`: Johor
- `22-24`: Kedah  
- `25-26`: Kelantan
- `27`: Kuala Lumpur
- `28-29`: Labuan
- `30-32`: Malacca
- And many more...

## Future Enhancements

- Complete survey form implementation
- Advanced demographic analysis
- Export functionality for survey data
- Multi-language support
- Enhanced security features

## Support

For technical issues or questions about the Malaysian IC parsing logic, refer to the test files or examine the `HeadsUp.Surveys.SurveyToken` module.
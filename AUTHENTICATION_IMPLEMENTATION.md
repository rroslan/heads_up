# Authentication Implementation Summary

This document explains the authentication model implemented for the HeadsUp survey token system.

## Authentication Model

The system implements a two-tier authentication approach designed for survey distribution:

### 1. Token Generation (Authenticated Users Only)
- **Route**: `/token`
- **Access Level**: Requires user authentication (any registered user)
- **Purpose**: Allows registered users to generate survey tokens for distribution
- **Use Case**: Researchers, survey administrators, or registered users create tokens to share with participants

### 2. Survey Access (No Authentication Required)
- **Route**: `/survey/:token`
- **Access Level**: Public access with valid token
- **Purpose**: Allows anyone with a valid token link to complete the survey
- **Use Case**: Survey participants (who may not be registered users) can access and complete surveys

## Implementation Details

### Router Configuration

```elixir
# Public routes (no authentication)
scope "/", HeadsUpWeb do
  pipe_through :browser
  
  get "/", PageController, :home
  live "/survey/:token", TokenLive.Survey, :show  # Public survey access
end

# Authenticated routes (logged-in users only)
scope "/", HeadsUpWeb do
  pipe_through [:browser, :require_authenticated_user]
  
  live_session :require_authenticated_user,
    on_mount: [{HeadsUpWeb.UserAuth, :require_authenticated}] do
    live "/token", TokenLive.Landing, :new  # Token generation for authenticated users
    # ... other authenticated routes
  end
end
```

### LiveView Authentication Hooks

**Token Generation (`TokenLive.Landing`)**:
```elixir
defmodule HeadsUpWeb.TokenLive.Landing do
  use HeadsUpWeb, :live_view
  
  # Requires user authentication
  on_mount {HeadsUpWeb.UserAuth, :require_authenticated}
  
  # ... rest of implementation
end
```

**Survey Access (`TokenLive.Survey`)**:
```elixir
defmodule HeadsUpWeb.TokenLive.Survey do
  use HeadsUpWeb, :live_view
  
  # No authentication hook - public access with token validation
  
  # ... rest of implementation
end
```

## Security Features

1. **Token Generation Security**:
   - Requires user registration and login
   - Only authenticated users can generate tokens
   - Prevents anonymous token creation

2. **Survey Access Security**:
   - Token-based access control
   - Cryptographically secure tokens
   - Time-limited (24-hour expiration)
   - One-time use tokens
   - No user registration required for participants

3. **Session Management**:
   - Standard Phoenix/Elixir session handling
   - Remember-me functionality for token generators
   - Secure cookie configuration

## User Experience Flow

### For Token Generators (Registered Users)
1. Register/Login to the system
2. Navigate to `/token`
3. Enter Malaysian IC number
4. Generate survey token
5. Share token URL with survey participants

### For Survey Participants (Unregistered Users)
1. Receive token URL from registered user
2. Click link to access `/survey/:token`
3. Complete survey without registration
4. Token becomes invalid after completion

## Benefits of This Approach

1. **Low Barrier for Participants**: Survey takers don't need to register
2. **Controlled Distribution**: Only registered users can create tokens
3. **Secure Token Management**: Prevents unauthorized token generation
4. **Flexible Sharing**: Tokens can be shared via any medium (email, messaging, etc.)
5. **Privacy**: Participants don't need to provide personal information to the system

## Testing Coverage

The implementation includes comprehensive tests covering:

- Authentication requirements for token generation
- Public access to surveys with valid tokens
- Error handling for invalid/expired tokens
- Complete user workflow scenarios
- Cross-session token sharing
- Form validation and reset functionality

## Configuration

Authentication is configured through the existing `HeadsUpWeb.UserAuth` module, which provides:

- `require_authenticated`: For token generation routes
- Session management and cookie handling
- Flash message handling for authentication errors
- Redirect logic for unauthorized access

## Migration Notes

When updating from the previous implementation:

1. **Token Generation**: Now requires user authentication (previously admin-only)
2. **Survey Access**: Now public (previously required authentication)
3. **User Interface**: Updated messaging to reflect authentication requirements
4. **Documentation**: Updated to reflect new authentication model

This authentication model balances security with usability, ensuring controlled token distribution while maintaining accessibility for survey participants.
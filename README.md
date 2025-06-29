# HeadsUp

A Phoenix LiveView application with magic link authentication and comprehensive user management system.

## 🚀 Features

### Authentication
- **Magic Link Only**: Secure, passwordless authentication via email
- **Role-Based Access Control**: Admin, Editor, and Regular user roles
- **Session Management**: Secure token-based sessions with automatic cleanup

### User Management
- **Admin-Only Registration**: New users can only be created by administrators
- **Comprehensive User Interface**: Full CRUD operations for user management
- **Role Assignment**: Granular role management with real-time updates
- **Magic Link Distribution**: Send login links to unconfirmed users
- **User Status Tracking**: Monitor confirmation status and registration dates

### Security
- **Authorization Layers**: Protected routes with role-based access
- **Input Validation**: Comprehensive email and role validation
- **Self-Protection**: Admins cannot delete themselves
- **Secure Tokens**: Time-limited magic link tokens

## 🛠 Technology Stack

- **Phoenix Framework** - Web framework
- **Phoenix LiveView** - Real-time UI components
- **Ecto** - Database ORM
- **PostgreSQL** - Database
- **Tailwind CSS + DaisyUI** - Styling
- **ExUnit** - Testing framework

## 📦 Installation

1. **Clone and setup:**
   ```bash
   git clone <repository-url>
   cd heads_up
   mix setup
   ```

2. **Create initial users:**
   ```bash
   mix run priv/repo/seeds.exs
   ```

3. **Start the server:**
   ```bash
   mix phx.server
   ```

4. **Visit the application:**
   ```
   http://localhost:4000
   ```

## 👥 User Roles

### Administrator (`is_admin: true`)
- Full access to user management interface (`/users`)
- Can register new users with any role
- Can modify user roles
- Can delete users (except themselves)
- Can send magic links to users
- Access to all application features

### Editor (`is_editor: true`)
- Content editing capabilities (framework ready)
- Cannot access user management
- Standard user permissions

### Regular User
- Basic authenticated access
- Can access personal settings
- Cannot manage other users

## 🔐 Authentication Flow

1. **Login Request**: User enters email at `/users/log-in`
2. **Magic Link Generation**: System generates secure token and sends email
3. **Link Verification**: User clicks link to authenticate
4. **Session Creation**: Secure session established
5. **Role-Based Redirect**: User directed to appropriate interface

## 🎯 User Management Interface

Access: `/users` (Admin only)

### Features:
- **User Registration Form**
  - Email validation
  - Role assignment (Admin/Editor checkboxes)
  - Automatic magic link delivery

- **User List Table**
  - Email addresses
  - Confirmation status (Confirmed/Pending badges)
  - Role indicators (Admin/Editor badges)
  - Registration dates
  - Action buttons (Edit/Delete/Send Login Link)

- **Role Management Modal**
  - Edit user roles with live preview
  - Role descriptions and permissions
  - Bulk role updates

- **Delete Confirmation**
  - Safety confirmation modal
  - Prevention of self-deletion
  - Permanent deletion warning

## 🗂 Project Structure

```
lib/
├── heads_up/
│   ├── accounts.ex                 # User context with CRUD operations
│   └── accounts/
│       ├── user.ex                 # User schema with roles
│       ├── user_token.ex           # Magic link tokens
│       ├── user_notifier.ex        # Email notifications
│       └── scope.ex                # User scope/session context
├── heads_up_web/
│   ├── live/user_live/
│   │   ├── management.ex           # 🆕 Admin user management interface
│   │   ├── login.ex                # Magic link login
│   │   ├── settings.ex             # User settings
│   │   └── confirmation.ex         # Email confirmation
│   ├── user_auth.ex                # Authentication plugs and helpers
│   ├── router.ex                   # Route definitions with protection
│   └── components/
│       └── layouts.ex              # 🆕 Enhanced navigation with user context
test/
└── heads_up_web/live/user_live/
    └── management_test.exs          # 🆕 Comprehensive test suite (19 tests)
priv/repo/
└── seeds.exs                       # 🆕 Development user seeds
```

## 🧪 Testing

The application includes a comprehensive test suite with 31 passing tests:

```bash
# Run all tests
mix test

# Run user management tests only
mix test test/heads_up_web/live/user_live/management_test.exs

# Run with coverage
mix test --cover
```

### Test Coverage:
- ✅ Access control and authorization
- ✅ User registration with roles
- ✅ Role management operations
- ✅ Delete user functionality
- ✅ Magic link generation and sending
- ✅ Form validation and error handling
- ✅ UI interactions and modal behavior

## 🚀 Getting Started

### Development Setup

1. **Create admin user** (automatically via seeds):
   ```
   Email: admin@example.com
   Role: Administrator
   ```

2. **Login process**:
   - Visit `http://localhost:4000/users/log-in`
   - Enter `admin@example.com`
   - Check console logs for magic link (development mode)
   - Click link to authenticate

3. **Access user management**:
   - Navigate to `/users` or click "Manage Users" in header
   - Register new users with appropriate roles
   - Manage existing user permissions

### Production Setup

1. **Configure email adapter** in `config/prod.exs`
2. **Set up proper email service** (SendGrid, Mailgun, etc.)
3. **Configure database** with production credentials
4. **Set environment variables** for secrets
5. **Deploy** using your preferred method

## 📧 Email Configuration

The application uses magic links for authentication. Configure your email adapter:

**Development** (Local):
```elixir
# config/dev.exs
config :heads_up, HeadsUp.Mailer, adapter: Swoosh.Adapters.Local
```

**Production** (Example with SendGrid):
```elixir
# config/prod.exs
config :heads_up, HeadsUp.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: System.get_env("SENDGRID_API_KEY")
```

## 🔧 Configuration Options

### User Session Settings
- **Session validity**: 14 days (configurable in `user_auth.ex`)
- **Token reissue**: 7 days (configurable)
- **Sudo mode timeout**: 10 minutes for sensitive operations

### Security Settings
- **Magic link expiration**: Configurable in `UserToken`
- **CSRF protection**: Enabled by default
- **Secure headers**: Configured in router pipeline

## 🚦 API Endpoints

### Public Routes
- `GET /` - Home page
- `GET /users/log-in` - Login form
- `POST /users/log-in` - Magic link request
- `GET /users/log-in/:token` - Magic link verification
- `DELETE /users/log-out` - Logout

### Protected Routes (Authenticated)
- `GET /users/settings` - User settings
- `POST /users/update-password` - Password operations

### Admin Routes (Admin Only)
- `GET /users` - User management interface
- All user CRUD operations via LiveView

## 🔧 Recent Updates

### Navigation Fix
- ✅ **Removed duplicate navigation bars**: Fixed issue where there were two navigation bars causing logout errors
- ✅ **Improved logout functionality**: Updated logout links to use proper Phoenix method attributes
- ✅ **Single navigation system**: Now uses only the main header navigation with proper user context

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Write comprehensive tests for new features
- Follow Phoenix conventions and patterns
- Update documentation for API changes
- Ensure all tests pass before submitting

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Check the [Phoenix documentation](https://hexdocs.pm/phoenix)
- Review the [LiveView guides](https://hexdocs.pm/phoenix_live_view)
- Open an issue for bugs or feature requests

---

**Built with ❤️ using Phoenix LiveView**
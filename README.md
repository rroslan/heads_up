# Heads Up

Heads Up is a comprehensive monitoring and notification platform designed to keep you informed about critical events and system status in real-time. With customizable alerts, detailed dashboards, and robust admin capabilities, Heads Up provides everything you need to stay on top of your systems.

## Features

### Authentication System
- Secure user authentication with email/password
- Session management with remember-me functionality
- Role-based authorization (admin vs regular users)
- User settings management

### Admin Dashboard
- Admin-only access control
- System metrics and status overview
- User management tools
- Activity monitoring capabilities

### User Interface
- Responsive design that works on desktop and mobile
- Dark/light/system theme support with persistent preferences
- Intuitive navigation with user role-based menu items
- Flash messaging system for user feedback

### Technical Features
- Built with Phoenix LiveView for real-time updates
- Tailwind CSS with DaisyUI components for styling
- PostgreSQL database for data persistence
- Secure password hashing with Bcrypt

## Setup Instructions

### Development Environment

To start your Heads Up server:

1. Clone the repository
2. Set up the database:
   ```bash
   mix ecto.setup
   ```
3. Install dependencies:
   ```bash
   mix deps.get
   cd assets && npm install
   ```
4. Start Phoenix server:
   ```bash
   mix phx.server
   ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

### Creating an Admin User

To create your first admin user:

1. Register a regular user through the UI
2. Use the provided script to promote the user to admin:
   ```bash
   # Set the admin email
   export ADMIN_EMAIL="your-email@example.com"
   
   # Run the make_admin script
   mix run priv/repo/scripts/make_admin.exs
   ```

Alternatively, create a new admin user directly:
```bash
export ADMIN_EMAIL="admin@example.com"
export ADMIN_PASSWORD="your-secure-password"
mix run priv/repo/scripts/create_admin_user.exs
```

### Production Deployment

For production deployment:

1. Set appropriate environment variables
2. Compile assets with:
   ```bash
   mix assets.deploy
   ```
3. Run migrations on production:
   ```bash
   mix ecto.migrate
   ```

Ready to run in production? Please [check the Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Project Structure

```
lib/heads_up/
├── accounts/           # User authentication and management
├── application.ex      # Application supervisor
├── repo.ex             # Database repository

lib/heads_up_web/
├── components/         # UI components and layouts
├── controllers/        # HTTP controllers
├── live/               # LiveView pages
│   ├── admin/          # Admin-only pages
│   ├── user_live/      # User authentication pages
│   └── home_live.ex    # Main landing page
├── plugs/              # Custom plugs for auth/admin
├── router.ex           # Application routes
└── user_auth.ex        # Authentication logic
```

## Learn more

* Official Phoenix website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

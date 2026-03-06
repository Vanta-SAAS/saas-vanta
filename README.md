# VANTA - SaaS ERP

Multi-tenant ERP system for Peruvian businesses. Manages quotes, sales, purchases, dispatch, inventory, and SUNAT electronic invoicing.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Ruby 3.3.6 |
| Framework | Rails 8.0 |
| Database | PostgreSQL 16 |
| Frontend | Tailwind CSS, Hotwire (Turbo + Stimulus), Importmap |
| Assets | Propshaft |
| Jobs | Solid Queue (database-backed, no Redis) |
| PDF | wicked_pdf + wkhtmltopdf |
| Email | Resend |
| Storage | Cloudflare R2 (S3-compatible) via Active Storage |
| Tests | RSpec + FactoryBot + Faker |
| Linting | RuboCop (rubocop-rails-omakase) |
| Security | Brakeman |
| Container | Docker + Docker Compose |

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)
- That's it. No need to install Ruby, Node, or PostgreSQL locally.

## Getting Started

### 1. Clone the repository

```bash
git clone <repo-url>
cd saas-vanta
```

### 2. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` with your values. Minimum variables for local development:

```env
# Database (defaults work out of the box)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=saas_vanta_development
DATABASE_URL=postgres://postgres:postgres@db:5432/saas_vanta_development
DATABASE_URL_TEST=postgres://postgres:postgres@db:5432/saas_vanta_test

# Application
RAILS_ENV=development

# Mailer (required for user invitations)
RESEND_API_KEY=your_api_key_here
```

### 3. Start the services

```bash
docker compose up
```

This automatically:
- Builds the app image (`Dockerfile.dev`)
- Starts PostgreSQL 16
- Installs gems (`bundle install`)
- Creates/migrates the database (`db:prepare`)
- Runs seeds (`db:seed`) — loads roles and ubigeos
- Compiles Tailwind CSS
- Starts the server at `http://localhost:3000`

### 4. Create the first enterprise and user

Use the Rails console to create the first super admin:

```bash
docker exec -it saas-vanta-app bash -c "bin/rails console"
```

```ruby
# Create enterprise
enterprise = Enterprise.create!(
  comercial_name: "My Company",
  email: "admin@mycompany.com"
)

# Create platform super admin user
user = User.create!(
  first_name: "Admin",
  first_last_name: "User",
  email_address: "admin@mycompany.com",
  password: "password123",
  password_confirmation: "password123",
  status: :active,
  platform_role: :super_admin
)

# Link user to enterprise with super_admin role
ue = UserEnterprise.create!(user: user, enterprise: enterprise)
role = Role.find_by(slug: :super_admin)
UserEnterpriseRole.create!(user_enterprise: ue, role: role)
```

Go to `http://localhost:3000` and sign in with the email and password you created.

## Common Commands

All commands run inside the Docker container:

```bash
# Rails console
docker exec -it saas-vanta-app bash -c "bin/rails console"

# Migrations
docker exec saas-vanta-app bash -c "bin/rails db:migrate"

# Seeds
docker exec saas-vanta-app bash -c "bin/rails db:seed"

# Tests
docker exec saas-vanta-app bash -c "bundle exec rspec"

# Run a specific test file
docker exec saas-vanta-app bash -c "bundle exec rspec spec/models/sale_spec.rb"

# Run a specific test by line number
docker exec saas-vanta-app bash -c "bundle exec rspec spec/models/sale_spec.rb:42"

# Linting
docker exec saas-vanta-app bash -c "bundle exec rubocop"
docker exec saas-vanta-app bash -c "bundle exec rubocop -a"  # auto-correct

# Security audit
docker exec saas-vanta-app bash -c "bundle exec brakeman"

# Shell inside the container
docker exec -it saas-vanta-app bash
```

## Architecture

### Multi-Tenancy

Users belong to one or more enterprises through `user_enterprises`. The session stores the active `enterprise_id`. All business data is scoped to an enterprise.

```
User --< UserEnterprise >-- Enterprise
              |
              v
        UserEnterpriseRole >-- Role
```

### Roles & Authorization

There are two permission levels:

**Platform Role** (`platform_role` field on User):
- `standard` — regular user
- `super_admin` — full platform access (manage enterprises, etc.)

**Enterprise Roles** (via `user_enterprise_roles`):
A user can have **multiple roles** per enterprise:

| Role | Slug | Access |
|------|------|--------|
| Super Administrador | `super_admin` | Full enterprise management |
| Administrador | `admin` | Full enterprise management |
| Vendedor | `seller` | Quotes, sales, and customers |
| Conductor | `driver` | Dispatch guides and shipping |

Authorization is handled by Pundit-style policies in `app/policies/`. Controllers call `authorize(record, action)` via the `Authorization` concern.

### Document Flow

```
CustomerQuote (COT) --accept!--> Sale (VTA) --generate_purchase_orders!--> PurchaseOrder(s) (OC)
```

- Origin is tracked with `sourceable` (polymorphic association)
- `Sale.sourceable` → `CustomerQuote`
- `PurchaseOrder.sourceable` → `Sale`
- Dropshipping is controlled by `enterprise.settings.dropshipping_enabled?`

Three document models share behavior through concerns:

| Model | Code Prefix | Items Model | Concern |
|-------|-------------|-------------|---------|
| `CustomerQuote` | COT | `CustomerQuoteItem` | `Documentable` |
| `Sale` | VTA | `SaleItem` | `Documentable` |
| `PurchaseOrder` | OC | `PurchaseOrderItem` | `Documentable` |

**Key concerns:**
- `Documentable` (models): associations, status, `calculate_totals` on `before_save`, `generate_next_code`
- `LineItemCalculable` (items): product, quantity, unit price, `total = quantity * unit_price`
- `PdfExportable` (controllers): shared PDF generation with wicked_pdf

### Tax Calculation

`PeruTax` module: IGV 18%. Unit prices include tax.

```ruby
PeruTax.base_amount(total)  # Extract the base amount
PeruTax.extract_igv(total)  # Extract the IGV tax
```

### SUNAT — Electronic Invoicing

Integration with an external microservice for electronic document emission:

- **Config:** `BILLING_BASE_URL` (default: `http://localhost:8000/api/v1`)
- **Services:** `app/services/sunat/` (registration, certificate upload, emission, status check, retry)
- **Document types:** Factura (01) for customers with RUC, Boleta (03) for customers with DNI
- **Fields on Sale:** `sunat_uuid`, `sunat_status`, `sunat_document_type`, `sunat_series`, `sunat_number`

### Services

Services inherit from `BaseService` which provides `@errors`, `valid?`, `add_error(msg)`, and `set_as_invalid!`. Subclasses implement `#call`.

```ruby
service = MyService.new(params)
service.call
if service.valid?
  # success
else
  service.errors_message # error string
end
```

### Background Jobs

Solid Queue (database-backed, no Redis). Currently used for `BulkImportJob`.

## Project Structure

```
app/
├── controllers/
│   ├── concerns/
│   │   ├── authorization.rb        # Authorization concern (authorize)
│   │   └── pdf_exportable.rb       # Shared PDF generation
│   ├── sales_controller.rb
│   ├── customer_quotes_controller.rb
│   ├── purchase_orders_controller.rb
│   ├── dispatch_guides_controller.rb
│   ├── sunat_controller.rb         # SUNAT configuration
│   └── ...
├── models/
│   ├── concerns/
│   │   ├── documentable.rb         # Shared document logic
│   │   └── line_item_calculable.rb # Item calculation
│   ├── sale.rb
│   ├── customer_quote.rb
│   ├── purchase_order.rb
│   ├── enterprise.rb
│   ├── enterprise_setting.rb       # Per-enterprise settings
│   ├── user.rb
│   ├── role.rb                     # super_admin, admin, seller, driver
│   └── ...
├── policies/                       # Pundit-style authorization
├── services/
│   ├── base_service.rb
│   ├── users/                      # User invitation
│   └── sunat/                      # Electronic invoicing
├── helpers/
│   ├── application_helper.rb       # Sidebar, breadcrumbs, icons
│   └── users_helper.rb             # Role and status badges
├── views/
│   ├── layouts/
│   │   ├── application.html.erb    # Main layout with sidebar
│   │   └── auth.html.erb           # Authentication layout
│   ├── shared/
│   │   ├── _sidebar.html.erb       # Main navigation
│   │   ├── _breadcrumbs.html.erb
│   │   ├── table/                  # Reusable table components
│   │   └── documents/              # Shared status bar
│   └── ...
└── javascript/
    └── controllers/                # Stimulus controllers
        ├── sidebar_controller.js
        ├── nav_group_controller.js
        └── toast_controller.js
```

## Important Gotchas

### Nested Attributes Callback Order

The parent's `before_save` fires **BEFORE** children's `before_save`. In `Documentable#calculate_totals`, compute item totals inline:

```ruby
# CORRECT — calculate inline
items_total = items.reject(&:marked_for_destruction?).sum { |item|
  (item.quantity || 0) * (item.unit_price || 0)
}

# WRONG — item.total hasn't been calculated yet
items_total = items.sum(&:total)
```

### Re-save Parent After Creating Children

If you create items via association, you must re-save the parent to trigger `calculate_totals`:

```ruby
sale = Sale.create!(...)
sale.items.create!(product: product, quantity: 2, unit_price: 100)
sale.save!  # <- required to recalculate totals
```

### Rails Form Helpers and Nested Attributes

`f.hidden_field "items_attributes[#{index}][id]"` generates wrong names. Use `hidden_field_tag` with an explicit name:

```ruby
# CORRECT
hidden_field_tag "sale[items_attributes][#{index}][id]", item.id

# WRONG
f.hidden_field "items_attributes[#{index}][id]"
```

### Exclude Destroyed Items

Always use `reject(&:marked_for_destruction?)` in `calculate_totals` to exclude items marked for deletion.

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection URL | Yes |
| `RAILS_ENV` | Environment (development/test/production) | Yes |
| `RESEND_API_KEY` | Resend API key for emails | Yes (invitations) |
| `BILLING_BASE_URL` | SUNAT microservice URL | No (default: localhost:8000) |
| `R2_CLIENT_ID` | Cloudflare R2 access key | Production |
| `R2_SECRET_KEY` | Cloudflare R2 secret key | Production |
| `R2_S3_ENDPOINT` | Cloudflare R2 endpoint | Production |
| `R2_BUCKET` | R2 bucket name | Production |
| `SECRET_KEY_BASE` | Rails secret key | Production |

## Seeds

Seeds are loaded automatically when the container starts. They live in `db/seeds/`:

- `01_roles.rb` — Creates the 4 roles (Super Admin, Admin, Vendedor, Conductor)
- `02_ubigeos.rb` — Loads Peru's ubigeos (department/province/district)

## Testing

```bash
# Full suite
docker exec saas-vanta-app bash -c "bundle exec rspec"

# By type
docker exec saas-vanta-app bash -c "bundle exec rspec spec/models/"
docker exec saas-vanta-app bash -c "bundle exec rspec spec/requests/"
docker exec saas-vanta-app bash -c "bundle exec rspec spec/services/"

# Verbose output
docker exec saas-vanta-app bash -c "bundle exec rspec --format documentation"
```

Test data is created with FactoryBot. Factories are in `spec/factories/`.

## Visual Theme

The app supports light and dark mode. The toggle is in the sidebar (Configuration section).

- **Light mode:** Warm off-white surfaces, subtle borders, emerald accent
- **Dark mode:** Dark surfaces, borders for definition, desaturated semantic colors
- Design tokens are defined in `app/assets/tailwind/application.css`
- Depth strategy: borders-only (no shadows)

## License

Proprietary. All rights reserved.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Environment

All commands run inside Docker. The app container is `saas-vanta-app`.

```bash
# Start services
docker compose up

# Run any Rails/Ruby command
docker exec saas-vanta-app bash -c "COMMAND"

# Rails console
docker exec saas-vanta-app bash -c "bin/rails console"

# Database (use :with_data to include data migrations)
docker exec saas-vanta-app bash -c "bin/rails db:migrate:with_data"
docker exec saas-vanta-app bash -c "bin/rails db:seed"
```

## Testing & Linting

```bash
# Run all tests
docker exec saas-vanta-app bash -c "bundle exec rspec"

# Run single test file
docker exec saas-vanta-app bash -c "bundle exec rspec spec/models/sale_spec.rb"

# Run specific test by line
docker exec saas-vanta-app bash -c "bundle exec rspec spec/models/sale_spec.rb:42"

# Lint
docker exec saas-vanta-app bash -c "bundle exec rubocop"
docker exec saas-vanta-app bash -c "bundle exec rubocop -a"  # auto-correct

# Security
docker exec saas-vanta-app bash -c "bundle exec brakeman"
```

RSpec with FactoryBot + Faker. Tests in `spec/` (models, requests, services, factories).

## Architecture

**Ruby 3.3.6, Rails 8.0, PostgreSQL 16, Tailwind CSS, Hotwire (Turbo + Stimulus), Importmap, Propshaft**

### Multi-Tenant SaaS

Users belong to one or more enterprises via `user_enterprises`. Sessions store the active `enterprise_id`. All business data is scoped to an enterprise.

### Document System

Three document types share behavior through concerns:

| Model | Code Prefix | Items Model |
|-------|------------|-------------|
| `CustomerQuote` | COT | `CustomerQuoteItem` |
| `Sale` | VTA | `SaleItem` |
| `PurchaseOrder` | OC | `PurchaseOrderItem` |

**Key concerns:**
- `Documentable` (models): enterprise/customer/seller associations, status, `calculate_totals` on `before_save`, `generate_next_code`
- `LineItemCalculable` (items): product association, `total = quantity * unit_price` on `before_save`
- `PdfExportable` (controllers): shared PDF generation with wicked_pdf

**Document flow:**
```
CustomerQuote → accept! → Sale → generate_purchase_orders! → PurchaseOrder(s)
```
Polymorphic `sourceable` tracks origin. Dropshipping controlled by `enterprise.settings.dropshipping_enabled?`.

### Tax Calculation

`PeruTax` module: IGV 18%. Unit prices include tax. `PeruTax.base_amount(total)` extracts the base, `PeruTax.extract_igv(total)` extracts the tax.

### Services

Services inherit from `BaseService` which provides `@errors`, `valid?`, `add_error(msg)`, and `set_as_invalid!`. Subclasses implement `#call`.

### Auth

- **Authentication**: Rails 8 `has_secure_password`, session-based (`Session` model), rate-limited login
- **Authorization**: Custom Pundit-style policies in `app/policies/`. Controllers call `authorize(record, action)` via `Authorization` concern. `PolicyContext` provides `user` + `enterprise`.

### SUNAT Integration (Electronic Invoicing)

External microservice at `BILLING_BASE_URL` (default: `http://localhost:8000/api/v1`). Services in `app/services/sunat/` handle registration, certificate upload, document emission, status checking. Sales carry `sunat_*` fields (uuid, status, document_type, series, number). Factura (01) for RUC customers, Boleta (03) for DNI customers.

### Background Jobs

Solid Queue (database-backed, no Redis). Currently used for `BulkImportJob`.

## Important Gotchas

- **Nested attributes callback order**: Parent `before_save` fires BEFORE children's `before_save`. In `Documentable#calculate_totals`, compute item totals inline: `(item.quantity || 0) * (item.unit_price || 0)` — do not rely on `item.total`.
- **Exclude destroyed items**: Use `reject(&:marked_for_destruction?)` in `calculate_totals`.
- **Rails form helper name generation**: `f.hidden_field "items_attributes[#{index}][id]"` generates wrong names. Use `hidden_field_tag` with explicit name format.
- **Re-save parent after creating children** via association to trigger `calculate_totals`.

## Code Style

Rubocop with `rubocop-rails-omakase`. 2-space indentation, spaces only. UI text and error messages are in Spanish.

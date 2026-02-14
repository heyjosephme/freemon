# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
bin/setup              # First-time setup (installs gems, prepares DB, starts server)
bin/dev                # Start dev server (Rails + Tailwind watcher via foreman)
bin/rails test         # Run unit/integration tests
bin/rails test:system  # Run system tests (Capybara + Selenium)
bin/rails test test/models/user_test.rb           # Run a single test file
bin/rails test test/models/user_test.rb:42        # Run a single test by line number
bin/rubocop            # Lint (rubocop-rails-omakase style)
bin/rubocop -a         # Lint with auto-correct
bin/ci                 # Full local CI: setup, rubocop, bundler-audit, importmap audit, brakeman, tests, seed test
```

## Architecture

**Rails 8.1 on Ruby 4.0** with SQLite for everything (no Redis, no Node/npm).

### View Layer: Phlex (not ERB)

Views and components are Ruby classes using Phlex, not ERB templates. ERB is only used for the layout (`app/views/layouts/application.html.erb`) and mailer templates.

- **`Components::Base`** (`app/components/base.rb`) — base for reusable UI components, inherits `Phlex::HTML`. Includes Rails route helpers. In development, injects HTML comments before each component for debugging.
- **`Views::Base`** (`app/views/base.rb`) — base for page views, inherits `Components::Base`. Has Phlex fragment caching enabled.
- `Components` extends `Phlex::Kit`, so `Components::Button` can be called as just `Button(...)` inside other Phlex components.
- Autoloading: `Views` module loads from `app/views/`, `Components` from `app/components/` (configured in `config/initializers/phlex.rb`).

### Asset Pipeline

- **Propshaft** (not Sprockets)
- **Tailwind CSS** via `tailwindcss-rails` gem (standalone CLI, no npm). Entry point: `app/assets/tailwind/application.css`
- **JavaScript** via import maps only (`importmap-rails`). Controllers in `app/javascript/controllers/`. No webpack/esbuild/bundler.
- **Hotwire**: Turbo + Stimulus included

### Database-Backed Infrastructure (Solid Trilogy)

No external services needed. All backed by SQLite:
- **Solid Cache** — `Rails.cache`
- **Solid Queue** — Active Job backend (runs inside Puma via `SOLID_QUEUE_IN_PUMA=true` in production)
- **Solid Cable** — Action Cable adapter

### Domain: Japanese Freelancer Tax & Bookkeeping

**Core models:** `FiscalYear` → `SalaryIncome`, `Revenue`, `Expense`, `Deduction` (tax data), `JournalEntry` → `JournalEntryLine` (bookkeeping), `Account` (chart of accounts)

**Double-entry bookkeeping (複式簿記):** Revenue/Expense records auto-generate journal entries via `JournalEntrySync` service (after_save callbacks). Manual journal entries also supported. Accounting method: 税込経理方式 (tax-inclusive).

**Tax calculators** (`app/services/`): `IncomeTaxCalculator` and `ConsumptionTaxCalculator` read from Revenue/Expense models directly. Journal entries are a parallel bookkeeping layer.

**Financial reports** (computed from journal entries): 仕訳帳 (Journal), 総勘定元帳 (General Ledger), 損益計算書 (P&L), 貸借対照表 (Balance Sheet)

**Money:** All amounts are integers (yen). No floats. Tax extraction: `amount * 10 / 110` (multiply first). Taxable income rounded down to nearest ¥1,000.

### Testing

- **Minitest** with parallel workers (`number_of_processors`)
- All fixtures loaded globally (`fixtures :all`)
- System tests use Capybara + Selenium

### Deployment

Kamal 2 with Docker. Single-server SQLite setup. Production data persisted in `freemon_storage:/rails/storage` volume. Thruster wraps Puma in production. `bin/docker-entrypoint` runs `db:prepare` on boot.

## Style

- Linting: `rubocop-rails-omakase` (no custom overrides)
- Use `# frozen_string_literal: true` in new Ruby files (matches existing convention in Phlex files)

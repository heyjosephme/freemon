# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
bin/setup              # First-time setup (installs gems, prepares DB, starts server)
bin/dev                # Start dev server (Rails + Tailwind watcher via foreman)
bin/rails test         # Run unit/integration tests (test:prepare builds Tailwind first)
bin/rails test test/services/income_tax_calculator_test.rb      # Run a single test file
bin/rails test test/services/income_tax_calculator_test.rb:14   # Run a single test by line number
bin/rails test:system  # Run system tests (needs Chrome for the two JavaScript tests)
bin/rubocop            # Lint (rubocop-rails-omakase style)
bin/rubocop -a         # Lint with auto-correct
bin/ci                 # Full local CI: setup, rubocop, bundler-audit, importmap audit, brakeman, tests, system tests, seed test
bin/rails revenues:import FILE=sales.csv          # Bulk-import revenues from a CSV (dry run; add COMMIT=1 to save)
bin/rails expenses:import FILE=expenses.csv       # Same for expenses
bin/freemon setup | bin/freemon | bin/freemon backup [DIR] | bin/freemon restore DIR   # The user's personal instance (see below)
```

`bin/brakeman` is the stock Rails binstub, which prepends `--ensure-latest`: it exits 5 whenever a newer Brakeman has been released, even with zero warnings. Fix with `bundle update brakeman`; `bundle exec brakeman` scans without the version gate. GitHub Actions (`.github/workflows/ci.yml`) runs the same checks on every branch push.

## Architecture

**Rails 8.1 on Ruby 4.0** with SQLite for everything (no Redis, no Node/npm).

### View Layer: Phlex (not ERB)

Views and components are Ruby classes using Phlex, not ERB templates. ERB is only used for the layout (`app/views/layouts/application.html.erb`) and mailer templates.

- **`Components::Base`** (`app/components/base.rb`) — base for reusable UI components, inherits `Phlex::HTML`. Includes Rails route helpers. In development, injects HTML comments before each component for debugging.
- **`Views::Base`** (`app/views/base.rb`) — base for page views, inherits `Components::Base`. Has Phlex fragment caching enabled.
- Controllers render views explicitly, passing everything as keyword args: `render Views::FiscalYears::Show.new(fiscal_year: @fiscal_year, reserve: ...)`.
- `Components` extends `Phlex::Kit`, so `Button(...)` works inside Phlex classes, but the codebase convention is `render Button.new(...)` (bare constant, no `Components::` prefix).
- Autoloading: `Views` module loads from `app/views/`, `Components` from `app/components/` (configured in `config/initializers/phlex.rb`).
- Format yen with the `MoneyDisplay` component (or `ActiveSupport::NumberHelper`). Don't add `helpers.` calls: phlex-rails 2.4 deprecates `helpers` and its next minor release removes it (the Gemfile's `~> 2.4` allows that release). The existing `helpers.number_to_currency` calls in index views predate this.
- Charts are server-rendered with no JS library: `Components::Charts::MonthlyCashflow` is a `Phlex::SVG` (not a `Components::Base`), `Components::Charts::ProportionBars` is plain HTML bars.

### Asset Pipeline

- **Propshaft** (not Sprockets)
- **Tailwind CSS v4** via `tailwindcss-rails` gem (standalone CLI, no npm). CSS-first config: the entry point `app/assets/tailwind/application.css` is just `@import "tailwindcss";` and there is no `tailwind.config.js`. Tailwind only emits classes it finds verbatim in source, so build class strings from complete literal class names and use inline `style` for computed values (see `ProportionBars`).
- **JavaScript** via import maps only (`importmap-rails`). Controllers in `app/javascript/controllers/`. No webpack/esbuild/bundler.
- **Hotwire**: Turbo + Stimulus included

### Database-Backed Infrastructure (Solid Trilogy)

No external services needed. In **production**, all backed by SQLite, each in its own database file (`storage/production{,_cache,_queue,_cable}.sqlite3`):
- **Solid Cache** — `Rails.cache`
- **Solid Queue** — Active Job backend (runs inside Puma via `SOLID_QUEUE_IN_PUMA=true` in production). `db/queue_schema.rb` predates the optional batch tables added in Solid Queue 1.7, which 2.0 will require (`bin/rails solid_queue:update` adds the migration).
- **Solid Cable** — Action Cable adapter

Development and test use a single SQLite file and Rails' simple adapters instead (dev: `memory_store` cache, async jobs and cable; test: `null_store` cache, test adapters).

**Active Storage** uses the Disk service in every environment (`storage/`, or `STORAGE_DIR` when set; `tmp/storage` in test).

### Domain: Japanese Freelancer Tax & Bookkeeping

Everything except the chart of accounts is scoped to a `FiscalYear` (one per calendar year; `filing_type` is 青色65 / 青色10 / 白色) and nested under `fiscal_years` in the routes. Reports and analysis pages are member routes on it.

`/` redirects to `FiscalYear.home` (this year, else the most recent earlier year, else the latest), and the navbar switches years. The app runs on Tokyo time (`config.time_zone`), so "this year" turns over at midnight JST. From January to March, this year's and last year's dashboards link to last year's open 確定申告 (`FiscalYear#open_filing_deadlines`).

The year dashboard (`Views::FiscalYears::Show`) is ordered by how often each part is used: 経費 (daily, with a quick-add row) beside 事業収入 (monthly), then the once-a-year 給与所得 and 所得控除, then reports and analysis. Expense and revenue forms opened from it carry `return_to=dashboard` (whitelisted in the `ReturnsToDashboard` controller concern), so saving or cancelling goes back to the dashboard instead of the list. New entries default to today in the current year (`FiscalYear#default_entry_date`).

**Core models:** `FiscalYear` → `SalaryIncome`, `Revenue`, `Expense`, `Deduction` (tax data), `JournalEntry` → `JournalEntryLine` (bookkeeping), `Account` (chart of accounts). Uploaded documents: `Revenue has_many_attached :invoices`, `Expense has_many_attached :receipts`. Assigning to a `has_many_attached` replaces the whole collection, so edit forms resubmit every kept file's `signed_id` through `Components::AttachedFiles` (checked checkboxes; unchecking one deletes that file). `Expense#invoice_eligible` has three values: true, false, or nil when the user doesn't track it (fine under 簡易課税 and 2割特例). It defaults to nil, so nothing is credited by accident. Only true earns 本則課税's input tax credit. `invoice_eligible?` is false for nil too, so compare with `== false` where "no invoice" and "unset" must differ (the expense list only flags the former). `Expense#purchase_channel` is `in_person` (default) or `online`; online purchases get e-receipts by email, so `receipt_missing?` only flags in-person expenses without an attached receipt.

**Two expense figures — don't mix them up:** `Expense#amount` is the full tax-included amount paid; `#deductible_amount` applies 家事按分 (`business_ratio`). Tax calculations use the 按分後 figure (`FiscalYear#total_expenses`); `CashflowReport` uses the full amount (実額); journal entries debit the deductible part to the expense account and the personal part to 事業主貸 (190).

**Assets (設備・資産):** an expense's `kind` is `ordinary` (経費) or `asset`. An asset's `accounting_method` is `immediate_expense` (under ¥100,000), `small_asset_special` (¥100,000 to under ¥400,000, 青色申告 only, ¥3,000,000 a year), `lump_sum_3_year` (¥100,000 to under ¥200,000) or `normal_depreciation` (定額法 over `useful_life`, prorated by month, down to ¥1). A blank method is suggested from the amount and filing type, and the thresholds are `Expense` constants. `Expense#write_off_schedule` (year → amount before 家事按分) is the single source for all three consumers:
- the tax side: `FiscalYear#total_expenses` counts this year's share of assets from earlier years too, via `depreciable_assets`;
- the journal entries;
- the 減価償却費の計算 report (`/fiscal_years/:id/depreciation`).

**Double-entry bookkeeping (複式簿記):** Revenue/Expense `after_save` callbacks rebuild their journal entries via `JournalEntrySync`, which posts to hard-coded account codes:
- `102` 普通預金, `103` 売掛金, `190` 事業主貸, `401` 売上高, plus `CATEGORY_ACCOUNT_MAP`;
- for assets: `150` 工具器具備品, `151` 一括償却資産, `152` ソフトウェア, `511` 減価償却費.

How assets post:
- 少額特例 goes straight to 減価償却費.
- Lump-sum and depreciated assets get a purchase entry to their asset account, then a year-end 減価償却費 entry (private share to 事業主貸) in every `FiscalYear` that exists. A year created later posts its share (`FiscalYear` after_create). So `Expense has_many :journal_entries`; `Revenue` still has one.

The accounts come from `db/seeds.rb`, plus a migration that added the asset ones to existing databases. Sync is skipped entirely while no accounts exist (`if Account.any?`). Manual journal entries are also supported. Accounting method: 税込経理方式 (tax-inclusive).

**Financial reports** (computed from journal entries): 仕訳帳 (Journal), 総勘定元帳 (General Ledger), 損益計算書 (P&L), 貸借対照表 (Balance Sheet). The P&L and B/S aggregation lives in the view classes (`Views::FiscalYears::IncomeStatement`, `BalanceSheet`), not in services.

The B/S carries asset, liability and equity balances over from earlier years; 事業主貸/事業主借 count this year only, and 元入金 is computed from earlier years (there's no account for it). There are no opening balances or receivable collections yet, so 普通預金 can go negative and 売掛金 only grows.

**Tax services** (`app/services/`) read Revenue/Expense/Deduction directly; journal entries are a parallel bookkeeping layer.
- `IncomeTaxCalculator` — the root calculation; returns a Hash. The `extra_income_deductions:` / `extra_business_expenses:` kwargs model hypothetical contributions.
- `ConsumptionTaxCalculator` — 本則課税 / 簡易課税 / 2割特例, recommends the cheapest.
- `ResidentTaxEstimator`, `HealthInsuranceEstimator` — 住民税 / 国保 概算. They take an `IncomeTaxCalculator` result hash, not a `FiscalYear`. Rates are tunable constants (国保 defaults model 東京23区, ~2024).
- `TaxReserveEstimator` — sums all four into "how much to set aside"; drives the dashboard banner and the `tax_reserve` page.
- `TaxSavingSimulator` — re-runs the calculators with hypothetical 小規模企業共済 / iDeCo contributions (所得控除: lowers income and resident tax, not 国保) and 経営セーフティ共済 (必要経費: also lowers 国保).
- `CashflowReport` — monthly in/out plus by-client and by-category breakdowns, at full amounts (see above).

**Bulk import:** `RevenueImport` and `ExpenseImport` (behind `bin/rails revenues:import` / `expenses:import`, both in `lib/tasks/import.rake`) read hand-made CSVs in UTF-8 or Shift_JIS; examples are in `test/fixtures/files/`. They share `CsvImport`, which checks every row before saving anything, saves all-or-nothing, files each row under the fiscal year of its date, and skips rows identical to an existing record (each subclass's `IDENTITY`), so re-running a file is safe. Subclasses declare `MODEL`, `IDENTITY` and `COLUMNS` (header aliases, required or optional) and implement `#attributes_for`.

**Tax rules are not year-aware:** brackets, deductions, rates and the asset thresholds are constants in each class (e.g. `IncomeTaxCalculator::BASIC_DEDUCTION`, `SalaryIncome::DEDUCTION_BRACKETS`, `Expense::SMALL_ASSET_LIMIT`) and apply to every fiscal year. 基礎控除 is also hard-coded as `480_000` in `Views::Deductions::Index`.

**Money:** All amounts are integer yen (columns and return values). Tax extraction: `amount * 10 / 110` (multiply first). Taxable income rounded down to nearest ¥1,000. The older calculators multiply by float rates and truncate with `.to_i`; the newer estimators use integer percent / basis points so results are exact — prefer that for new code. Display percentages are floats rounded to 1 dp.

`MVP_concept.md` is the original product brief. It targets a React app (ignore the stack), but its tax rules are the spec the services implement.

### Testing

- **Minitest**, parallelized with `number_of_processors` (Rails only forks workers once there are ≥50 tests)
- **No fixture files exist** (`fixtures :all` is configured but loads nothing). Tests create records inline in `setup`, by convention `FiscalYear.create!(year: 2099, ...)`. Service tests assert exact yen amounts with the arithmetic in comments.
- Most tests don't load seeds, so whether `JournalEntrySync` runs depends on leftover DB state. A fresh test DB (GitHub Actions, parallel workers) has no `Account` rows and the `Account.any?` guard skips sync, but `bin/ci`'s seed step leaves the seeded accounts in `storage/test.sqlite3`, so later local runs do sync. Tests of journal entries or the P&L/B/S load the chart of accounts with `load Rails.root.join("db/seeds.rb")` in `setup` (its sample data is development-only), as `journal_entry_sync_test.rb` and `depreciation_test.rb` do.
- **System tests** (`test/system/`) inherit `ApplicationSystemTestCase` (Selenium + headless Chrome by default). Tests that don't need JavaScript opt into `driven_by :rack_test`, which submits forms exactly as rendered without a browser; most do. `year_switcher_test.rb` and `asset_fields_test.rb` are the real-browser ones. Upload fixtures live in `test/fixtures/files/`.
- Date-dependent behavior is tested with `travel_to` (see `test/integration/current_year_test.rb`).

### Personal instance (`bin/freemon`)

The user keeps their real books in a separate local instance, not in development: `bin/freemon` runs the app in **production mode** with data in `FREEMON_HOME` (default `~/Library/Application Support/Freemon`: `storage/` for the SQLite databases and uploads, plus the secret key and TLS certificate), served at https://freemon.localhost:4443. **Never read or change that data unless the user asks**; it holds their real finances. Development data stays sample data.

- `STORAGE_DIR` relocates the production databases (`config/database.yml`) and the Disk service root (`config/storage.yml`); unset, both stay in `storage/` as before.
- `FREEMON_HOST`, set only by `bin/freemon`, makes `config/environments/production.rb` accept just that host (blocking DNS rebinding; the app has no login), force SSL, and serve assets live via Propshaft (`config.assets.server`) so nothing is precompiled into the repo's `public/assets`, which would shadow development's assets.
- `config/puma.rb` binds `ssl://127.0.0.1` when `SSL_CERT_PATH` is set (certificates come from mkcert). The launcher runs Puma directly, because `rails server` binds 0.0.0.0 outside development.
- `bin/freemon COMMAND` passes any other command to `bin/rails` with the instance's environment. Production is a protected environment, so Rails refuses `db:reset`, `db:drop` and the like there.
- `Freemon::Backup` (`lib/freemon/backup.rb`, behind `freemon:backup DIR=` / `freemon:restore FROM=`) snapshots the primary database with `VACUUM INTO` plus the upload folders; cache, queue and cable databases are rebuildable and skipped.

### Deployment

Kamal 2 with Docker. Single-server SQLite setup. Production data persisted in `freemon_storage:/rails/storage` volume; this holds the SQLite databases *and* Active Storage uploads. Thruster wraps Puma in production. `bin/docker-entrypoint` runs `db:prepare` on boot. `config/deploy.yml` still has the generator's placeholder server (`192.168.0.1`) and registry (`localhost:5555`).

## Style

- Linting: `rubocop-rails-omakase` (no custom overrides)
- Use `# frozen_string_literal: true` in new Ruby files (matches existing convention in app and test code)
- UI copy is Japanese with an English gloss in parentheses (`"経費 (Expenses)"`); flash notices are Japanese only.

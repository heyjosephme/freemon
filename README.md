# Freemon

A personal tax and bookkeeping app for a Japanese freelancer (個人事業主), built around the yearly 確定申告: income and consumption tax calculations, double-entry bookkeeping (複式簿記), cashflow, and tax planning.

> これは税務シミュレーションツールです。参考用としてご利用ください。正式な申告には税理士にご相談ください。

## Features

- **確定申告**: income tax combining 給与所得 and 事業所得 (青色申告特別控除, 損益通算, 復興特別所得税), and consumption tax compared across 本則課税 / 簡易課税 / 2割特例.
- **Bookkeeping**: revenues and expenses (家事按分, インボイス対応, attached invoices and receipts) post journal entries automatically, and manual entries are supported. Reports: 仕訳帳, 総勘定元帳, 損益計算書, 貸借対照表.
- **Analysis and planning**: monthly cashflow, how much to set aside for 所得税・消費税・住民税・国保, and what 小規模企業共済 / iDeCo / 経営セーフティ共済 contributions would save.
- **Current-year home page**: opens this year's dashboard, and from January to March links to last year's open 確定申告 and its deadlines.
- **Bulk revenue import** from a CSV ([below](#importing-revenues-from-a-csv)).

## Requirements

- Ruby 4.0.0 (see `.ruby-version`) and SQLite 3
- Google Chrome, for the one browser-based system test
- Optional: libvips (`brew install vips`), used to analyze uploaded image receipts

## Getting started

```bash
bin/setup   # installs gems, creates the database, starts the app
bin/dev     # afterwards: starts Rails and the Tailwind watcher
```

Then open http://localhost:3000. The development database is seeded with the chart of accounts (勘定科目) and a sample 2025 fiscal year.

All data, the SQLite databases and uploaded files alike, lives in `storage/`, which git ignores. Back it up.

## Importing revenues from a CSV

Write a CSV with a header row:

```csv
日付,取引先,金額
2026-07-31,株式会社テックコープ,"¥550,000"
2026/8/31,合同会社デザインラボ,220000
```

```bash
bin/rails revenues:import FILE=sales.csv            # dry run: lists what would be saved
bin/rails revenues:import FILE=sales.csv COMMIT=1   # saves
```

- Amounts are tax-included yen (税込); `¥`, `円`, commas and full-width digits are all accepted.
- Dates can be written `2026-07-31`, `2026/7/31` or `2026年7月31日`. Each row is filed under the fiscal year of its date, which must already exist.
- Files can be UTF-8 or Excel's Shift_JIS.
- Nothing is saved if any row has an error, and rows identical to an existing revenue are skipped, so re-running a file is safe.

## Development

```bash
bin/rails test          # unit and integration tests
bin/rails test:system   # system tests
bin/rubocop             # lint
bin/ci                  # everything CI checks: lint, security audits, tests, seeds
```

GitHub Actions runs the same checks on every branch push. Architecture notes for working on the code are in [CLAUDE.md](CLAUDE.md).

## Known limitations

- Tax rules are fixed constants applied to every year. They predate the 2025 (令和7年) reform that raised 基礎控除 and the 給与所得控除 minimum, so for most incomes the app overstates income tax for 2025 onward.
- 2割特例 is always offered, but it only applies to eligible businesses for tax years up to 2026.
- 住民税 and 国保 are estimates. 国保 uses 東京23区 rates from around 2024 and doesn't model 軽減.

## Deployment

The app is set up for Kamal 2 on a single server with SQLite; the databases and uploads live in the `freemon_storage` volume. `config/deploy.yml` still has placeholder server and registry values, so it hasn't been deployed yet.

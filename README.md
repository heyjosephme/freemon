# Freemon

A personal tax and bookkeeping app for a Japanese freelancer (個人事業主), built around the yearly 確定申告: income and consumption tax calculations, double-entry bookkeeping (複式簿記), cashflow, and tax planning.

> これは税務シミュレーションツールです。参考用としてご利用ください。正式な申告には税理士にご相談ください。

## Features

- **確定申告**: income tax combining 給与所得 and 事業所得 (青色申告特別控除, 損益通算, 復興特別所得税), and consumption tax compared across 本則課税 / 簡易課税 / 2割特例.
- **Bookkeeping**: revenues and expenses (家事按分, インボイス対応, online or in-person purchase, attached invoices and receipts) post journal entries automatically, and manual entries are supported. In-person expenses still missing a receipt photo are flagged. Reports: 仕訳帳, 総勘定元帳, 損益計算書, 貸借対照表.
- **Equipment and other assets** (設備・資産) are deducted the way the rules say, picked from the amount if you don't choose:
  - under ¥100,000: in full when bought;
  - under ¥400,000: in full via 少額減価償却資産の特例 (青色申告, ¥3,000,000 a year);
  - ¥100,000 to under ¥200,000: optionally 一括償却, a third a year for three years;
  - anything larger: 定額法 depreciation over its 耐用年数.
  
  Each year's share flows into 所得税 and the journal entries, and the 減価償却 page lays it out like the 青色申告決算書's 減価償却費の計算.
- **Analysis and planning**: monthly cashflow, how much to set aside for 所得税・消費税・住民税・国保, and what 小規模企業共済 / iDeCo / 経営セーフティ共済 contributions would save.
- **Expense-first dashboard**: opens on this year, with 経費 front and centre (a quick-add row for everyday entries) beside 事業収入, and the once-a-year sections tucked below. From January to March it links to last year's open 確定申告 and its deadlines.
- **Bulk import** of revenues and expenses from CSV ([below](#importing-revenues-and-expenses-from-csv)).

## Requirements

- Ruby 4.0.0 (see `.ruby-version`) and SQLite 3
- Google Chrome, for the two browser-based system tests
- Optional: libvips (`brew install vips`), used to analyze uploaded image receipts

## Getting started (development)

```bash
bin/setup   # installs gems, creates the database, starts the app
bin/dev     # afterwards: starts Rails and the Tailwind watcher
```

Then open http://localhost:3000. The development database (`storage/development.sqlite3`, ignored by git) is seeded with the chart of accounts (勘定科目) and a sample 2025 fiscal year. It's for working on the code and safe to reset; keep your real books in the personal instance below.

## Using it for your own books

Your real data runs as a separate, private instance: production mode, data kept outside the repo in `~/Library/Application Support/Freemon`, served over HTTPS at https://freemon.localhost:4443.

```bash
brew install mkcert && mkcert -install   # once: lets this Mac trust the local certificate (asks for your password)
bin/freemon setup                        # once: data folder, secret key, certificate, database
bin/freemon                              # start, then open https://freemon.localhost:4443
```

- **Other commands** go through `bin/freemon` too, so they reach your data instead of the development database: `bin/freemon expenses:import FILE=expenses.csv`, `bin/freemon console`.
- **Backups:** `bin/freemon backup [DIR]` snapshots the database and receipts, safely even while the app runs. `bin/freemon restore DIR` puts one back, after first backing up the current state. Keep copies off this Mac (an external disk, say), but don't put the live data folder itself in iCloud or Dropbox, where syncing can corrupt SQLite.
- **Updates:** after a `git pull`, the next `bin/freemon` applies any migrations.
- **Safety:** Rails refuses destructive database tasks (`db:reset`, `db:drop`, …) against this instance. There's no login, so it only listens on 127.0.0.1 and only answers to `freemon.localhost`; don't expose it to a network.

## Importing revenues and expenses from CSV

Both imports read a hand-made CSV with a header row. They show a dry run first and only save with `COMMIT=1`:

```bash
bin/rails revenues:import FILE=sales.csv            # dry run: lists what would be saved
bin/rails revenues:import FILE=sales.csv COMMIT=1   # saves
bin/rails expenses:import FILE=expenses.csv         # the same for expenses
```

For your real books, run them through `bin/freemon` instead of `bin/rails`.

Revenues need 日付, 取引先 and 金額:

```csv
日付,取引先,金額
2026-07-31,株式会社テックコープ,"¥550,000"
2026/8/31,合同会社デザインラボ,220000
```

Expenses need 日付, 内容 and 金額; カテゴリ, 按分率, インボイス, 購入方法, 区分, 償却方法 and 耐用年数 are optional:

```csv
日付,内容,金額,カテゴリ,按分率,インボイス,購入方法
2026-07-01,MacBook Pro,298000,備品,80%,y,オンライン
2026-08-15,技術書,3520,書籍,,,店頭
```

- Amounts are tax-included yen (税込); `¥`, `円`, commas and full-width digits are all accepted.
- Dates can be written `2026-07-31`, `2026/7/31` or `2026年7月31日`. Each row is filed under the fiscal year of its date, which must already exist.
- カテゴリ takes any part of a category's name (`備品`, `器具`, `Equipment`, …). Blank カテゴリ and 按分率 cells mean その他 and 100%.
- インボイス is `y` (あり) or `n` (なし); `○` / `×` and `yes` / `no` work too. If you don't track invoices, leave it blank, write `null`, or leave the column out. That leaves the status 未設定, which is also where new expenses in the form start. Only 本則課税 uses it, and it never credits an unset expense; under 簡易課税 and 2割特例 it doesn't matter.
- 購入方法 is `オンライン` or `店頭`; blank means 店頭・対面. Online purchases get an e-receipt by email, so only in-person ones are flagged (要領収書) in the expense list until a receipt photo is attached.
- 区分 is `経費` (the default) or `資産`. For an asset, 償却方法 is `全額経費`, `特例`, `一括` or `定額`; leave it blank to pick one from the amount. 定額 needs 耐用年数 in years, e.g. `4` for a PC.
- Files can be UTF-8 or Excel's Shift_JIS.
- Nothing is saved if any row has an error, and rows identical to an existing record are skipped, so re-running a file is safe.

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
- The 少額減価償却資産の特例 limit is ¥400,000, following the 2026 rules; it was ¥300,000 before, and like the other rules it applies to every year.
- The balance sheet carries balances from year to year, but there are no opening balances or 売掛金 collections yet. 普通預金 can therefore go negative and 売掛金 only grows; record those with manual journal entries.

## Deployment

The app is set up for Kamal 2 on a single server with SQLite; the databases and uploads live in the `freemon_storage` volume. `config/deploy.yml` still has placeholder server and registry values, so it hasn't been deployed yet. The app has no login: for personal use, prefer the local instance above, and add authentication before ever deploying it.

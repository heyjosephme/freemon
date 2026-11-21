# frozen_string_literal: true

require "test_helper"

class DashboardLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @fiscal_year = FiscalYear.create!(year: 2099)
  end

  test "the year's result comes first, then catching up, entry and the once-a-year sections" do
    get fiscal_year_url(@fiscal_year)

    sections = [ 'id="year-summary"', 'id="business-profit"', 'id="catch-up"', 'id="quick-add-expense"',
                 "売上 (Revenue)</h2>", "給与所得 (Salary Income)", "所得控除 (Deductions)" ]
    positions = sections.map { |section| response.body.index(section) }
    assert positions.all?, "every section is on the page"
    assert_equal positions.sort, positions
  end

  test "the sidebar links the year's pages and marks the current one" do
    get fiscal_year_expenses_url(@fiscal_year)

    assert_select "nav a[aria-current=page]", text: "経費", count: 1
    assert_select "nav a[href=?]", fiscal_year_path(@fiscal_year), text: "ホーム"
    [ tax_summary_fiscal_year_path(@fiscal_year), cashflow_fiscal_year_path(@fiscal_year), balance_sheet_fiscal_year_path(@fiscal_year),
      fiscal_year_journal_entries_path(@fiscal_year), fixed_asset_tax_fiscal_year_path(@fiscal_year), edit_fiscal_year_path(@fiscal_year),
      new_fiscal_year_salary_income_path(@fiscal_year), recurring_expenses_path, accounts_path ].each do |path|
      assert_select "nav a[href=?]", path
    end
  end

  test "pages outside a year link into the home year" do
    travel_to Date.new(2099, 6, 1) do
      get accounts_url
      assert_select "nav summary", text: /2099年/
      assert_select "nav a[href=?]", fiscal_year_expenses_path(@fiscal_year), text: "経費"
      assert_select "nav a[aria-current=page]", text: "勘定科目"
    end
  end

  test "the summary shows the twelve months and marks the one in progress" do
    travel_to Date.new(2099, 3, 10) do
      @fiscal_year.revenues.create!(client_name: "取引先", amount: 100_000, date: Date.new(2099, 2, 28))

      get fiscal_year_url(@fiscal_year)
      assert_select "#year-summary svg text", count: 12
      assert_select "#year-summary svg rect.fill-primary", count: 1
      assert_select "#year-summary svg text.fill-ink", text: "3"

      get fiscal_year_url(FiscalYear.create!(year: 2098))
      assert_select "#year-summary svg text.fill-ink", count: 0
    end
  end

  test "catching up shows how far entry has got, months with no 売上 and receipts to attach" do
    travel_to Date.new(2099, 6, 10) do
      get fiscal_year_url(@fiscal_year)
      assert_select "#catch-up", text: /まだ入力がありません/
      assert_select "#catch-up", text: /確認が必要なものはありません/

      @fiscal_year.revenues.create!(client_name: "取引先", amount: 100_000, date: Date.new(2099, 2, 28))
      @fiscal_year.revenues.create!(client_name: "取引先", amount: 100_000, date: Date.new(2099, 4, 30))
      @fiscal_year.expenses.create!(description: "文房具", amount: 1_000, category: :other, date: Date.new(2099, 5, 2))
      @fiscal_year.expenses.create!(description: "サーバー", amount: 1_000, category: :other, purchase_channel: :online,
                                    date: Date.new(2099, 5, 20))

      get fiscal_year_url(@fiscal_year)
      assert_select "#catch-up", text: %r{入力済み: 経費 5/20 まで · 売上 4/30 まで}
      # February to May are over; January came before the first 売上 and June is still running.
      assert_select "#catch-up li", text: /売上の入力がない月:\s*3月・5月/
      assert_select "#catch-up li", text: /領収書が未添付の経費:\s*1件/ # the online one has an e-receipt
      assert_select "#catch-up", text: /確認が必要なものはありません/, count: 0
    end
  end

  test "a finished year isn't asked about its empty months" do
    travel_to Date.new(2099, 6, 10) do
      previous = FiscalYear.create!(year: 2097)
      previous.revenues.create!(client_name: "取引先", amount: 100_000, date: Date.new(2097, 2, 28))

      get fiscal_year_url(previous)
      assert_select "#catch-up", text: /売上の入力がない月/, count: 0
    end
  end

  test "this month's spending shows for the current year only" do
    previous = FiscalYear.create!(year: 2098)
    travel_to Date.new(2099, 3, 10) do
      @fiscal_year.expenses.create!(description: "今月", amount: 1_000, category: :other, date: Date.new(2099, 3, 1))
      @fiscal_year.expenses.create!(description: "先月", amount: 5_000, category: :other, business_ratio: 50,
                                    date: Date.new(2099, 2, 1))

      get fiscal_year_url(@fiscal_year)
      assert_select "#expense-totals", text: /今月\s*¥1,000/
      assert_select "#expense-totals", text: /¥3,500\s*按分後 · 2件/ # 1,000 + 5,000 × 50%

      get fiscal_year_url(previous)
      assert_select "#expense-totals", text: /今月/, count: 0
    end
  end

  test "net business income is revenue less expenses after 按分, before 消費税 and the blue deduction" do
    @fiscal_year.revenues.create!(client_name: "取引先", amount: 100_000, date: Date.new(2099, 1, 31))
    @fiscal_year.expenses.create!(description: "家賃", amount: 40_000, category: :office, business_ratio: 50,
                                  date: Date.new(2099, 1, 5))

    get fiscal_year_url(@fiscal_year)
    assert_select "#business-profit", text: /¥80,000/ # 100,000 − 40,000 × 50%; no 消費税, no 65万円 deduction
    assert_select "#business-profit", text: /消費税|租税公課/, count: 0
    assert_select "#business-profit", text: /青色申告特別控除前/
  end

  test "the settings form changes when 消費税 is expensed" do
    get edit_fiscal_year_url(@fiscal_year)
    assert_select "select[name='fiscal_year[consumption_tax_timing]'] option[selected][value=accrued]"

    patch fiscal_year_url(@fiscal_year), params: { fiscal_year: { consumption_tax_timing: "when_paid" } }
    assert @fiscal_year.reload.consumption_tax_when_paid?
  end

  test "a loss shows as a negative figure, and 白色 has no blue deduction to mention" do
    @fiscal_year.update!(filing_type: :white)
    @fiscal_year.expenses.create!(description: "機材", amount: 30_000, category: :other, date: Date.new(2099, 1, 5))

    get fiscal_year_url(@fiscal_year)
    assert_select "#business-profit .text-negative", text: "-¥30,000"
    assert_select "#business-profit", text: /青色申告特別控除前/, count: 0
  end

  test "without a target the card links to the settings" do
    get fiscal_year_url(@fiscal_year)
    assert_select "#business-profit-target", count: 0
    assert_select "#business-profit a[href=?]", edit_fiscal_year_path(@fiscal_year), text: /目標を設定/
  end

  test "a target shows the progress meter and what is left" do
    @fiscal_year.revenues.create!(client_name: "取引先", amount: 100_000, date: Date.new(2099, 1, 31))
    @fiscal_year.expenses.create!(description: "家賃", amount: 40_000, category: :office, business_ratio: 50,
                                  date: Date.new(2099, 1, 5))

    patch fiscal_year_url(@fiscal_year), params: { fiscal_year: { business_profit_target: 300_000 } }
    assert_redirected_to fiscal_year_url(@fiscal_year)
    follow_redirect!

    # 利益 80,000 ÷ 目標 300,000 = 26.6…% → 26%; 残り 220,000
    assert_select "#business-profit-target", text: /目標 \(Target\)\s*¥300,000/
    assert_select "#business-profit-target [role=meter][aria-valuenow='26'] div[style='width: 26%']"
    assert_select "#business-profit-target", text: /目標まであと \(To go\)\s*¥220,000/
  end

  test "past the target the meter stays full and the surplus is in the text" do
    @fiscal_year.update!(business_profit_target: 50_000)
    @fiscal_year.revenues.create!(client_name: "取引先", amount: 80_000, date: Date.new(2099, 1, 31))

    get fiscal_year_url(@fiscal_year)
    assert_select "#business-profit-target", text: /160%/ # 80,000 ÷ 50,000
    assert_select "#business-profit-target [role=meter] div[style='width: 100%']"
    assert_select "#business-profit-target", text: /目標達成.*\+¥30,000/m
  end

  test "a loss leaves the meter empty and adds the loss to what is left" do
    @fiscal_year.update!(business_profit_target: 50_000)
    @fiscal_year.expenses.create!(description: "機材", amount: 30_000, category: :other, date: Date.new(2099, 1, 5))

    get fiscal_year_url(@fiscal_year)
    assert_select "#business-profit-target", text: /0%/
    assert_select "#business-profit-target [role=meter] div", count: 0
    assert_select "#business-profit-target", text: /¥80,000/ # 50,000 + 30,000
  end

  test "the target must be a positive whole number of yen, or blank" do
    assert_not FiscalYear.new(year: 2098, business_profit_target: 0).valid?
    assert_not FiscalYear.new(year: 2098, business_profit_target: -1).valid?

    @fiscal_year.update!(business_profit_target: 50_000)
    patch fiscal_year_url(@fiscal_year), params: { fiscal_year: { business_profit_target: "" } }
    assert_nil @fiscal_year.reload.business_profit_target
  end

  test "the dashboard lists the latest eight expenses under their months, and three revenues" do
    1.upto(9) do |day|
      @fiscal_year.expenses.create!(description: "経費#{day}", amount: day * 100, category: :other, business_ratio: 50,
                                    date: Date.new(2099, day > 6 ? 2 : 1, day))
    end
    1.upto(6) { |day| @fiscal_year.revenues.create!(client_name: "取引先#{day}", amount: day, date: Date.new(2099, 1, day)) }
    get fiscal_year_url(@fiscal_year)

    assert_select "#recent-expenses a", count: 8
    assert_select "#recent-expenses a", text: /経費9/
    assert_select "#recent-expenses a", text: /経費1\b/, count: 0
    # Month headings carry the month's spending at full amounts: 700 + 800 + 900, and 100 + … + 600.
    assert_select "#recent-expenses li:not(:has(a))", count: 2
    assert_select "#recent-expenses li:not(:has(a))", text: /2月\s*支出 ¥2,400/
    assert_select "#recent-expenses li:not(:has(a))", text: /1月\s*支出 ¥2,100/
    assert_select "#recent-revenues li", count: 3
    assert_select "#recent-revenues a[href=?]", edit_fiscal_year_revenue_path(@fiscal_year, @fiscal_year.revenues.find_by!(client_name: "取引先6"), return_to: "dashboard")
  end

  test "an unexpected return_to can't redirect elsewhere" do
    post fiscal_year_expenses_url(@fiscal_year), params: {
      return_to: "https://example.com", expense: { description: "A", amount: 1000, category: "other", date: "2099-01-01" }
    }
    assert_redirected_to fiscal_year_expenses_url(@fiscal_year)
  end
end

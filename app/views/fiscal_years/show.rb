# frozen_string_literal: true

# A fiscal year's dashboard, ordered by how often each part is used: 経費
# (daily or weekly, with a quick-add row) beside 事業収入 (monthly), then the
# once-a-year 給与所得 and 所得控除, then reports and analysis.
class Views::FiscalYears::Show < Views::Base
  RECENT_EXPENSES = 5
  RECENT_REVENUES = 3
  CATEGORY_CHOICES = Expense::CATEGORY_LABELS.keys.map { |key| [ Expense.category_name(key), key ] }.freeze
  CHANNEL_CHOICES = Expense::PURCHASE_CHANNEL_LABELS.map { |key, label| [ label, key ] }.freeze
  QUICK_INPUT = "rounded-md border-0 py-1.5 px-2 text-sm text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600"

  def initialize(fiscal_year:, reserve:, filing_year: nil, start_current_year: false, recurring_bills: [])
    @fiscal_year = fiscal_year
    @reserve = reserve
    @filing_year = filing_year
    @start_current_year = start_current_year
    @recurring_bills = recurring_bills
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年", back_path: fiscal_years_path) do
      render Button.new(href: edit_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "設定" }
      render Button.new(href: tax_summary_fiscal_year_path(@fiscal_year), size: :sm) { "税額計算" }
    end

    div(class: "mb-4 flex gap-2") do
      render Badge.new(text: @fiscal_year.filing_type_label, color: @fiscal_year.white? ? :gray : :indigo)
      render Badge.new(text: "今年", color: :green) if current_year?
    end

    filing_banner
    start_year_banner
    reserve_banner

    div(class: "grid grid-cols-1 lg:grid-cols-3 items-start gap-6 mb-6") do
      div(class: "lg:col-span-2") { expense_section }
      revenue_section
    end

    div(class: "grid grid-cols-1 md:grid-cols-2 gap-6 mb-6") do
      salary_summary
      deduction_summary
    end

    div(class: "grid grid-cols-1 md:grid-cols-2 gap-6") do
      bookkeeping_links
      analysis_links
    end
  end

  private

  def current_year? = @fiscal_year.year == FiscalYear.current_year

  def filing_banner
    return unless @filing_year

    deadlines = @filing_year.open_filing_deadlines.map { |tax, date| "#{tax} #{date.month}/#{date.day}まで" }.join("・")
    div(class: "mb-6") do
      a(href: tax_summary_fiscal_year_path(@filing_year), class: "block") do
        div(class: "rounded-lg border border-amber-200 bg-amber-50 p-4 flex items-center justify-between hover:bg-amber-100 transition-colors") do
          div do
            p(class: "text-sm font-medium text-amber-800") { "#{@filing_year.year}年分の確定申告 (Tax filing)" }
            p(class: "text-xs text-amber-600 mt-0.5") { "期限: #{deadlines}" }
          end
          span(class: "text-sm font-medium text-amber-700 whitespace-nowrap") { "税額計算 →" }
        end
      end
    end
  end

  def start_year_banner
    return unless @start_current_year

    year = FiscalYear.current_year
    div(class: "mb-6 rounded-lg border border-emerald-200 bg-emerald-50 p-4 flex items-center justify-between") do
      div do
        p(class: "text-sm font-medium text-emerald-800") { "#{year}年の記録がまだありません" }
        p(class: "text-xs text-emerald-600 mt-0.5") { "申告種別（#{@fiscal_year.filing_type_label}）を引き継いで作成します。" }
      end
      button_to "#{year}年の帳簿を始める", fiscal_years_path,
        params: { fiscal_year: { year: year, filing_type: @fiscal_year.filing_type } },
        class: "inline-flex items-center px-3 py-1.5 rounded-md text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700 cursor-pointer"
    end
  end

  def reserve_banner
    return unless @fiscal_year.total_revenue.positive? || @fiscal_year.salary_income.present?

    div(class: "mb-6") do
      a(href: tax_reserve_fiscal_year_path(@fiscal_year), class: "block") do
        div(class: "rounded-lg border border-indigo-200 bg-indigo-50 p-4 flex items-center justify-between hover:bg-indigo-100 transition-colors") do
          div do
            p(class: "text-sm font-medium text-indigo-800") { "納税準備の目安 (Set aside for taxes)" }
            p(class: "text-xs text-indigo-500 mt-0.5") { "所得税・消費税・住民税・国保の概算合計 →" }
          end
          div(class: "text-right") do
            p(class: "text-2xl font-bold text-indigo-700") { yen(@reserve[:total]) }
            if @reserve[:revenue].positive?
              p(class: "text-xs text-indigo-500") { "売上の約#{@reserve[:reserve_rate]}%" }
            end
          end
        end
      end
    end
  end

  def expense_section
    expenses = @fiscal_year.expenses
    render Card.new do
      section_header("経費 (Expenses)") do
        render Button.new(href: new_fiscal_year_expense_path(@fiscal_year, return_to: "dashboard"), variant: :secondary, size: :sm) { "詳細入力" }
      end
      quick_add_expense
      recurring_bills

      div(id: "expense-totals", class: "flex flex-wrap gap-x-6 gap-y-1 text-sm mb-3") do
        total("今月", expenses.where(date: Date.current.all_month).sum(:amount)) if current_year?
        total("年間", @fiscal_year.total_expenses, note: "（按分後）")
        span(class: "text-gray-500") { "#{expenses.count}件" }
      end

      recent_entries(
        id: "recent-expenses", label: :description, empty: "まだ経費がありません。上の行から追加できます。",
        records: expenses.order(date: :desc, id: :desc).limit(RECENT_EXPENSES),
        edit_path: ->(expense) { edit_fiscal_year_expense_path(@fiscal_year, expense, return_to: "dashboard") }
      )
      list_link(fiscal_year_expenses_path(@fiscal_year))
    end
  end

  # Two short rows for routine expenses: 按分率 stays 100% and インボイス 未設定.
  # Anything more (receipts, 按分) goes through 詳細入力.
  def quick_add_expense
    form_with(model: Expense.new(date: @fiscal_year.default_entry_date), url: fiscal_year_expenses_path(@fiscal_year),
              id: "quick-add-expense", class: "space-y-2 mb-5") do |f|
      input(type: "hidden", name: "return_to", value: "dashboard")
      div(class: "flex flex-wrap gap-2") do
        f.label :date, "日付", class: "sr-only"
        f.date_field :date, required: true, class: "#{QUICK_INPUT} w-40"
        f.label :description, "内容", class: "sr-only"
        f.text_field :description, required: true, placeholder: "内容", class: "#{QUICK_INPUT} min-w-0 flex-1 basis-40"
        f.label :amount, "金額（税込）", class: "sr-only"
        f.number_field :amount, required: true, min: 1, placeholder: "金額（税込）", class: "#{QUICK_INPUT} w-36"
      end
      div(class: "flex flex-wrap items-center gap-2") do
        f.label :category, "カテゴリ", class: "sr-only"
        f.select :category, CATEGORY_CHOICES, {}, class: "#{QUICK_INPUT} w-44"
        f.label :purchase_channel, "購入方法", class: "sr-only"
        f.select :purchase_channel, CHANNEL_CHOICES, {}, class: "#{QUICK_INPUT} w-36"
        f.submit "追加", class: "ml-auto inline-flex items-center px-4 py-1.5 rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 cursor-pointer"
      end
    end
  end

  # 定期経費 due through this month and not recorded yet. Fixed amounts come filled
  # in and varying ones wait for theirs; each row records only when its button is
  # pressed, never on page load.
  def recurring_bills
    if @recurring_bills.empty?
      return unless RecurringExpense.exists?

      p(id: "recurring-bills", class: "mb-4 text-sm text-gray-500") do
        plain "定期経費: 未登録はありません ✓ "
        a(href: recurring_expenses_path, class: "text-indigo-600 hover:text-indigo-800") { "管理" }
      end
      return
    end

    div(id: "recurring-bills", class: "mb-5 rounded-md border border-amber-200 bg-amber-50 px-3 py-2") do
      div(class: "flex items-center justify-between gap-3") do
        h3(class: "text-sm font-medium text-amber-800") { "定期経費 (Recurring) 未登録 #{@recurring_bills.size}件" }
        a(href: recurring_expenses_path, class: "text-xs text-indigo-600 hover:text-indigo-800") { "管理 →" }
      end
      # A backlog (after months away, or a template started long ago) scrolls inside the box
      # rather than pushing the rest of the dashboard down.
      ul(class: "max-h-96 overflow-y-auto divide-y divide-amber-100") { @recurring_bills.each { |bill| recurring_bill(bill) } }
      record_all_fixed_bills
    end
  end

  def recurring_bill(bill)
    template = bill.recurring_expense
    name = "#{template.description} #{bill.month.month}月分"
    amount_id = "bill-#{template.id}-#{bill.month.strftime("%Y%m")}-amount"

    li do
      # One form per bill: 登録 records it; スキップ sends the same month to skip
      # (formaction) without needing an amount (formnovalidate).
      form_with(url: record_recurring_expense_path(template), class: "flex flex-wrap items-center gap-2 py-2") do
        input(type: "hidden", name: "month", value: bill.month.iso8601)
        span(class: "w-12 shrink-0 tabular-nums text-sm text-gray-500") { bill.date.strftime("%m/%d") }
        span(class: "min-w-0 flex-1 basis-32 truncate text-sm text-gray-800") do
          plain template.description
          span(class: "ml-2 text-xs text-gray-500") { "按分#{template.business_ratio}%" } if template.business_ratio < 100
        end
        label(for: amount_id, class: "sr-only") { "#{name}の金額" }
        input(type: "number", id: amount_id, name: "amount", value: template.amount, required: true, min: 1, placeholder: "金額",
              class: "#{QUICK_INPUT} w-28 text-right")
        button(type: "submit", class: "inline-flex items-center px-3 py-1.5 rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 cursor-pointer") { "登録" }
        button(type: "submit", formaction: skip_recurring_expense_path(template), formnovalidate: true,
               class: "text-xs text-gray-500 hover:text-gray-800 cursor-pointer", data: { turbo_confirm: "#{name}をスキップしますか？" }) { "スキップ" }
      end
    end
  end

  def record_all_fixed_bills
    fixed = @recurring_bills.count { |bill| bill.recurring_expense.fixed_amount? }
    return if fixed < 2

    div(class: "pt-1 pb-1 text-right") do
      button_to "固定額の#{fixed}件をまとめて登録", record_all_recurring_expenses_path, params: { fiscal_year_id: @fiscal_year.id },
        class: "text-sm font-medium text-indigo-600 hover:text-indigo-800 cursor-pointer"
    end
  end

  def revenue_section
    revenues = @fiscal_year.revenues
    render Card.new do
      section_header("事業収入 (Revenue)") do
        render Button.new(href: new_fiscal_year_revenue_path(@fiscal_year, return_to: "dashboard"), variant: :secondary, size: :sm) { "＋ 売上を追加" }
      end

      div(class: "flex flex-wrap gap-x-6 gap-y-1 text-sm mb-3") do
        total("年間", @fiscal_year.total_revenue)
        span(class: "text-gray-500") { "#{revenues.count}件" }
      end

      if revenues.none? && (previous = previous_year_to_copy_from)
        # In January, December's revenue to copy is in last year's list.
        p(class: "text-sm text-gray-400 py-2") do
          plain "まだ売上がありません。毎月の売上は"
          a(href: fiscal_year_revenues_path(previous), class: "text-indigo-600 hover:text-indigo-800") { "#{previous.year}年の一覧" }
          plain "から複製できます。"
        end
      else
        recent_entries(
          id: "recent-revenues", label: :client_name, empty: "まだ売上がありません。",
          records: revenues.order(date: :desc, id: :desc).limit(RECENT_REVENUES),
          edit_path: ->(revenue) { edit_fiscal_year_revenue_path(@fiscal_year, revenue, return_to: "dashboard") },
          copy_path: ->(revenue) { copy_revenue_path(revenue) }
        )
      end
      list_link(fiscal_year_revenues_path(@fiscal_year))
    end
  end

  # 複製: the new-revenue form filled in from this one, a month later, in that
  # month's fiscal year. None until that year has been started.
  def copy_revenue_path(revenue)
    fiscal_year = revenue.next_month_fiscal_year
    new_fiscal_year_revenue_path(fiscal_year, from_revenue: revenue.id, return_to: "dashboard") if fiscal_year
  end

  def previous_year_to_copy_from
    previous = FiscalYear.find_by(year: @fiscal_year.year - 1)
    previous if previous&.revenues&.exists?
  end

  def salary_summary
    salary = @fiscal_year.salary_income
    if salary
      summary_card("給与所得 (Salary Income)", value: yen(salary.salary_income_amount), detail: "支払金額 #{yen(salary.gross_salary)}",
                   link_text: "詳細", link_path: fiscal_year_salary_income_path(@fiscal_year))
    else
      summary_card("給与所得 (Salary Income)", detail: "未入力", link_text: "入力", link_path: new_fiscal_year_salary_income_path(@fiscal_year))
    end
  end

  def deduction_summary
    deductions = @fiscal_year.deductions
    count = deductions.count
    if count.positive?
      summary_card("所得控除 (Deductions)", value: yen(deductions.sum(:amount)), detail: "#{count}件 · 基礎控除は自動で計算",
                   link_text: "一覧", link_path: fiscal_year_deductions_path(@fiscal_year))
    else
      summary_card("所得控除 (Deductions)", detail: "未入力 · 基礎控除は自動で計算",
                   link_text: "追加", link_path: new_fiscal_year_deduction_path(@fiscal_year))
    end
  end

  def bookkeeping_links
    render Card.new(title: "帳簿・レポート (Bookkeeping & Reports)") do
      div(class: "flex flex-wrap gap-2") do
        render Button.new(href: fiscal_year_journal_entries_path(@fiscal_year), variant: :secondary, size: :sm) { "仕訳帳" }
        render Button.new(href: general_ledger_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "総勘定元帳" }
        render Button.new(href: income_statement_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "損益計算書" }
        render Button.new(href: balance_sheet_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "貸借対照表" }
        render Button.new(href: depreciation_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "減価償却" }
      end
    end
  end

  def analysis_links
    render Card.new(title: "分析・節税 (Analysis & Planning)") do
      div(class: "flex flex-wrap gap-2") do
        render Button.new(href: cashflow_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "キャッシュフロー" }
        render Button.new(href: tax_reserve_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "納税準備" }
        render Button.new(href: tax_saving_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "節税シミュレーション" }
      end
    end
  end

  def section_header(title, &actions)
    div(class: "flex items-center justify-between gap-3 mb-4") do
      h2(class: "text-lg font-semibold text-gray-900") { title }
      div(class: "flex items-center gap-2", &actions)
    end
  end

  def total(label, amount, note: nil)
    span(class: "text-gray-500") do
      plain "#{label} "
      span(class: "font-semibold text-gray-900") { yen(amount) }
      plain note if note
    end
  end

  # Latest entries, each linking to its edit form (which comes back here), plus
  # 複製 where copy_path gives a path for the entry.
  def recent_entries(id:, records:, label:, edit_path:, empty:, copy_path: nil)
    if records.empty?
      p(class: "text-sm text-gray-400 py-2") { empty }
      return
    end

    ul(id: id, class: "divide-y divide-gray-100") do
      records.each do |record|
        copy = copy_path&.call(record)
        li(class: "flex items-center gap-3") do
          a(href: edit_path.(record), class: "flex min-w-0 flex-1 items-baseline gap-3 py-2 px-2 -mx-2 rounded text-sm hover:bg-gray-50") do
            span(class: "w-12 shrink-0 tabular-nums text-gray-400") { record.date.strftime("%m/%d") }
            span(class: "min-w-0 flex-1 truncate text-gray-800") { record.public_send(label) }
            span(class: "tabular-nums text-gray-900") { yen(record.amount) }
          end
          a(href: copy, title: "翌月分として複製", class: "shrink-0 text-xs text-indigo-600 hover:text-indigo-800") { "複製" } if copy
        end
      end
    end
  end

  def list_link(path)
    div(class: "mt-3 text-right") do
      a(href: path, class: "text-sm text-indigo-600 hover:text-indigo-800") { "一覧 →" }
    end
  end

  # The once-a-year sections: one line with the key figure and a single link.
  def summary_card(title, detail:, link_text:, link_path:, value: nil)
    div(class: "bg-white rounded-lg shadow-sm border border-gray-200 px-5 py-4 flex items-center justify-between gap-4") do
      div(class: "min-w-0") do
        p(class: "text-sm font-medium text-gray-700") { title }
        p(class: "text-lg font-semibold text-gray-900") { value } if value
        p(class: "text-xs text-gray-500 truncate") { detail }
      end
      a(href: link_path, class: "shrink-0 text-sm text-indigo-600 hover:text-indigo-800") { link_text }
    end
  end

  def yen(amount) = "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"
end

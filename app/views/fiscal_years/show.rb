# frozen_string_literal: true

# A fiscal year's dashboard, for someone who comes back every week or month to
# enter a batch: where the year stands (事業利益, 売上, 経費, 納税準備 and the twelve
# months), then what has piled up since the last visit, then entry with the latest
# entries under it. The once-a-year 給与所得 and 所得控除 come last; reports are in
# the sidebar.
class Views::FiscalYears::Show < Views::Base
  RECENT_EXPENSES = 8
  RECENT_REVENUES = 3
  CATEGORY_CHOICES = Expense::CATEGORY_LABELS.keys.map { |key| [ Expense.category_name(key), key ] }.freeze
  CHANNEL_CHOICES = Expense::PURCHASE_CHANNEL_LABELS.map { |key, label| [ label, key ] }.freeze

  # entry_date: the date of the expense just added from here, so the next one in
  # the batch starts on the same day.
  def initialize(fiscal_year:, reserve:, months:, filing_year: nil, start_current_year: false, recurring_bills: [], entry_date: nil)
    @fiscal_year = fiscal_year
    @reserve = reserve
    @months = months
    @filing_year = filing_year
    @start_current_year = start_current_year
    @recurring_bills = recurring_bills
    @entry_date = entry_date if entry_date&.year == fiscal_year.year
  end

  def view_template
    div(class: "mb-6 flex flex-wrap items-center gap-3") do
      h1(class: "font-display text-3xl font-semibold tracking-wide text-ink") { "#{@fiscal_year.year}年" }
      render Badge.new(text: @fiscal_year.filing_type_label, color: @fiscal_year.white? ? :gray : :indigo)
      render Badge.new(text: "今年", color: :green) if current_year?
    end

    filing_banner
    start_year_banner
    year_summary
    catch_up

    div(class: "grid grid-cols-1 lg:grid-cols-5 items-start gap-6 mb-6") do
      div(class: "lg:col-span-3") { expense_section }
      div(class: "lg:col-span-2") { revenue_section }
    end

    div(class: "grid grid-cols-1 md:grid-cols-2 gap-6") do
      salary_summary
      deduction_summary
    end
  end

  private

  def current_year? = @fiscal_year.year == FiscalYear.current_year

  def filing_banner
    return unless @filing_year

    deadlines = @filing_year.open_filing_deadlines.map { |tax, date| "#{tax} #{date.month}/#{date.day}まで" }.join("・")
    div(class: "mb-6") do
      a(href: tax_summary_fiscal_year_path(@filing_year), class: "block") do
        div(class: "rounded-lg border border-warning-line bg-warning-soft px-5 py-4 flex items-center justify-between gap-4 hover:border-warning transition-colors") do
          div do
            p(class: "text-sm font-semibold text-warning") { "#{@filing_year.year}年分の確定申告 (Tax filing)" }
            p(class: "text-xs text-warning mt-0.5") { "期限: #{deadlines}" }
          end
          span(class: "text-sm font-medium text-warning whitespace-nowrap") { "税額計算 →" }
        end
      end
    end
  end

  def start_year_banner
    return unless @start_current_year

    year = FiscalYear.current_year
    div(class: "mb-6 rounded-lg border border-positive-line bg-positive-soft px-5 py-4 flex items-center justify-between gap-4") do
      div do
        p(class: "text-sm font-semibold text-positive") { "#{year}年の記録がまだありません" }
        p(class: "text-xs text-positive mt-0.5") { "申告種別（#{@fiscal_year.filing_type_label}）を引き継いで作成します。" }
      end
      button_to "#{year}年の帳簿を始める", fiscal_years_path,
        params: { fiscal_year: { year: year, filing_type: @fiscal_year.filing_type } },
        class: Button.classes(size: :sm)
    end
  end

  # Where the year stands: the result on the left, what it's made of and the twelve
  # months on the right.
  def year_summary
    section(id: "year-summary", class: "mb-6 grid grid-cols-1 rounded-lg border border-line bg-surface lg:grid-cols-5") do
      div(class: "p-6 lg:col-span-2") { business_profit }
      div(class: "border-t border-line p-6 lg:col-span-3 lg:border-l lg:border-t-0") do
        div(class: "grid grid-cols-2 gap-4 sm:grid-cols-3") do
          revenue_stat
          expense_stat
          reserve_stat
        end
        monthly_chart
      end
    end
  end

  def revenue_stat
    stat("売上 (Revenue)", yen(@fiscal_year.total_revenue)) { "#{@fiscal_year.revenues.count}件" }
  end

  def expense_stat
    expenses = @fiscal_year.expenses
    stat("経費 (Expenses)", yen(@fiscal_year.total_expenses), id: "expense-totals") do
      plain "按分後 · #{expenses.count}件"
      if current_year?
        br
        plain "今月 #{yen(expenses.where(date: Date.current.all_month).sum(:amount))}"
      end
    end
  end

  # 所得税・消費税・住民税・国保 together, once there is income to tax.
  def reserve_stat
    unless @fiscal_year.total_revenue.positive? || @fiscal_year.salary_income.present?
      return stat("納税準備の目安 (Set aside)", "—") { "収入を入力すると計算されます" }
    end

    stat("納税準備の目安 (Set aside)", yen(@reserve[:total]), href: tax_reserve_fiscal_year_path(@fiscal_year)) do
      plain "売上の約#{@reserve[:reserve_rate]}% · " if @reserve[:revenue].positive?
      plain "内訳 →"
    end
  end

  def stat(label, value, id: nil, href: nil, &detail)
    div(id: id, class: "min-w-0") do
      p(class: "text-xs text-muted") { label }
      p(class: "mt-1 text-xl font-semibold tabular-nums text-ink") { value }
      if href
        a(href: href, class: "mt-0.5 block text-xs #{LINK}", &detail)
      else
        p(class: "mt-0.5 text-xs text-muted", &detail)
      end
    end
  end

  # Cash in and out by month at full amounts (実額), unlike the 按分後 figure above.
  def monthly_chart
    div(class: "mt-6") do
      div(class: "mb-1 flex flex-wrap items-center justify-between gap-2 text-xs text-muted") do
        div(class: "flex items-center gap-4") do
          legend_item("bg-primary", "収入")
          legend_item("bg-negative", "支出（実額）")
        end
        a(href: cashflow_fiscal_year_path(@fiscal_year), class: LINK) { "キャッシュフロー →" }
      end
      render Components::Charts::MonthlyCashflow.new(months: @months, height: 150, cumulative: false,
                                                     current_month: (Date.current.month if current_year?))
    end
  end

  def legend_item(color, text)
    span(class: "inline-flex items-center gap-1.5") do
      span(class: "inline-block h-2.5 w-2.5 rounded-sm #{color}")
      plain text
    end
  end

  # What has piled up since the last visit: how far entry has got, the 定期経費 bills
  # not recorded yet, months with no 売上, and paper receipts still to attach.
  def catch_up
    notes = catch_up_notes
    div(class: "mb-6") do
      render Card.new do
        div(id: "catch-up") do
          div(class: "flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 mb-3") do
            h2(class: "text-base font-semibold text-ink") { "前回からの確認 (Catch up)" }
            p(class: "text-xs text-muted") { entered_through }
          end
          recurring_bills
          if notes.any?
            ul(class: "divide-y divide-line text-sm") do
              notes.each { |note| li(class: "flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 py-2", &note) }
            end
          elsif @recurring_bills.empty? && !RecurringExpense.exists?
            p(class: "text-sm text-muted") { "確認が必要なものはありません ✓" }
          end
        end
      end
    end
  end

  def entered_through
    last = { "経費" => @fiscal_year.expenses.maximum(:date), "売上" => @fiscal_year.revenues.maximum(:date) }.compact
    return "まだ入力がありません" if last.empty?

    "入力済み: " + last.map { |label, date| "#{label} #{date.month}/#{date.day} まで" }.join(" · ")
  end

  def catch_up_notes
    notes = []
    if (months = months_without_revenue).any?
      notes << proc do
        span(class: "text-ink") do
          span(class: "text-warning") { "売上の入力がない月: " }
          plain months.map { |month| "#{month}月" }.join("・")
        end
        a(href: new_fiscal_year_revenue_path(@fiscal_year, return_to: "dashboard"), class: LINK) { "売上を追加 →" }
      end
    end
    if (count = receipts_missing).positive?
      notes << proc do
        span(class: "text-ink") do
          span(class: "text-warning") { "領収書が未添付の経費: " }
          plain "#{count}件"
        end
        a(href: fiscal_year_expenses_path(@fiscal_year), class: LINK) { "経費一覧で確認 →" }
      end
    end
    notes
  end

  # Finished months with no 売上, from the first month that has any. Only while the
  # year is still being entered: this year, or last year until its 確定申告 is filed.
  def months_without_revenue
    return [] unless current_year? || @filing_year == @fiscal_year

    first = @months.find { |month| month.revenue.positive? }&.month
    last = current_year? ? Date.current.month - 1 : 12
    return [] unless first

    @months.select { |month| month.month.between?(first, last) && month.revenue.zero? }.map(&:month)
  end

  # In-person expenses with no photo of the paper receipt (Expense#receipt_missing?).
  def receipts_missing = @fiscal_year.expenses.in_person.where.missing(:receipts_attachments).count

  def expense_section
    expenses = @fiscal_year.expenses
    render Card.new do
      section_header("経費 (Expenses)") do
        render Button.new(href: new_fiscal_year_expense_path(@fiscal_year, return_to: "dashboard"), variant: :secondary, size: :sm) { "詳細入力" }
      end
      quick_add_expense

      recent_entries(
        id: "recent-expenses", label: :description, empty: "まだ経費がありません。上の行から追加できます。",
        records: expenses.order(date: :desc, id: :desc).limit(RECENT_EXPENSES), by_month: true,
        edit_path: ->(expense) { edit_fiscal_year_expense_path(@fiscal_year, expense, return_to: "dashboard") }
      )
      list_link(fiscal_year_expenses_path(@fiscal_year))
    end
  end

  # Two short rows for routine expenses: 按分率 stays 100% and インボイス 未設定.
  # Anything more (receipts, 按分) goes through 詳細入力. After an add, the date stays
  # and 内容 takes the focus, ready for the next one.
  def quick_add_expense
    form_with(model: Expense.new(date: @entry_date || @fiscal_year.default_entry_date), url: fiscal_year_expenses_path(@fiscal_year),
              id: "quick-add-expense", class: "space-y-2 mb-5") do |f|
      input(type: "hidden", name: "return_to", value: "dashboard")
      div(class: "flex flex-wrap gap-2") do
        f.label :date, "日付", class: "sr-only"
        f.date_field :date, required: true, class: "#{INPUT} w-40"
        f.label :description, "内容", class: "sr-only"
        f.text_field :description, required: true, placeholder: "内容", autofocus: @entry_date.present?, class: "#{INPUT} min-w-0 flex-1 basis-40"
        f.label :amount, "金額（税込）", class: "sr-only"
        f.number_field :amount, required: true, min: 1, placeholder: "金額（税込）", class: "#{INPUT} w-36"
      end
      div(class: "flex flex-wrap items-center gap-2") do
        f.label :category, "カテゴリ", class: "sr-only"
        f.select :category, CATEGORY_CHOICES, {}, class: "#{INPUT} w-44"
        f.label :purchase_channel, "購入方法", class: "sr-only"
        f.select :purchase_channel, CHANNEL_CHOICES, {}, class: "#{INPUT} w-36"
        f.submit "追加", class: "ml-auto #{Button.classes(size: :sm)}"
      end
    end
  end

  # 定期経費 due through this month and not recorded yet. Fixed amounts come filled
  # in and varying ones wait for theirs; each row records only when its button is
  # pressed, never on page load.
  def recurring_bills
    if @recurring_bills.empty?
      return unless RecurringExpense.exists?

      p(id: "recurring-bills", class: "mb-2 text-sm text-muted") do
        plain "定期経費: 未登録はありません ✓ "
        a(href: recurring_expenses_path, class: LINK) { "管理" }
      end
      return
    end

    div(id: "recurring-bills", class: "mb-3 rounded-md border border-warning-line bg-warning-soft px-3 py-2") do
      div(class: "flex items-center justify-between gap-3") do
        h3(class: "text-sm font-semibold text-warning") { "定期経費 (Recurring) 未登録 #{@recurring_bills.size}件" }
        a(href: recurring_expenses_path, class: "text-xs #{LINK}") { "管理 →" }
      end
      # A backlog (after months away, or a template started long ago) scrolls inside the box
      # rather than pushing the rest of the dashboard down.
      ul(class: "max-h-96 overflow-y-auto divide-y divide-warning-line") { @recurring_bills.each { |bill| recurring_bill(bill) } }
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
        span(class: "w-12 shrink-0 tabular-nums text-sm text-muted") { bill.date.strftime("%m/%d") }
        span(class: "min-w-0 flex-1 basis-32 truncate text-sm text-ink") do
          plain template.description
          span(class: "ml-2 text-xs text-muted") { "按分#{template.business_ratio}%" } if template.business_ratio < 100
        end
        label(for: amount_id, class: "sr-only") { "#{name}の金額" }
        input(type: "number", id: amount_id, name: "amount", value: template.amount, required: true, min: 1, placeholder: "金額",
              class: "#{INPUT} w-28 text-right")
        button(type: "submit", class: Button.classes(size: :sm)) { "登録" }
        button(type: "submit", formaction: skip_recurring_expense_path(template), formnovalidate: true,
               class: "text-xs text-muted hover:text-ink cursor-pointer", data: { turbo_confirm: "#{name}をスキップしますか？" }) { "スキップ" }
      end
    end
  end

  def record_all_fixed_bills
    fixed = @recurring_bills.count { |bill| bill.recurring_expense.fixed_amount? }
    return if fixed < 2

    div(class: "pt-1 pb-1 text-right") do
      button_to "固定額の#{fixed}件をまとめて登録", record_all_recurring_expenses_path, params: { fiscal_year_id: @fiscal_year.id },
        class: "text-sm font-medium #{LINK} cursor-pointer"
    end
  end

  def revenue_section
    revenues = @fiscal_year.revenues
    render Card.new do
      section_header("売上 (Revenue)") do
        render Button.new(href: new_fiscal_year_revenue_path(@fiscal_year, return_to: "dashboard"), variant: :secondary, size: :sm) { "＋ 売上を追加" }
      end

      if revenues.none? && (previous = previous_year_to_copy_from)
        # In January, December's revenue to copy is in last year's list.
        p(class: "text-sm text-muted py-2") do
          plain "まだ売上がありません。毎月の売上は"
          a(href: fiscal_year_revenues_path(previous), class: LINK) { "#{previous.year}年の一覧" }
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

  # 売上 − 経費（按分後）: what the business has earned so far, before 消費税（租税公課）and
  # 青色申告特別控除 (the tax summary applies those).
  def business_profit
    profit = @fiscal_year.business_profit
    div(id: "business-profit") do
      h2(class: "text-sm font-medium text-muted") { "事業利益 (Net business income)" }
      p(class: "mt-2 font-display text-4xl font-semibold tabular-nums #{profit.negative? ? "text-negative" : "text-ink"}") do
        plain profit.negative? ? "-#{yen(profit.abs)}" : yen(profit)
      end
      p(class: "mt-2 text-xs text-muted") do
        plain "売上 − 経費（按分後）"
        plain " · 青色申告特別控除前" if @fiscal_year.blue?
      end
      business_profit_target(profit)
    end
  end

  # Progress towards the year's target as a meter: one ratio against a limit, with the
  # figures printed beside it. The fill stops at 100% and the text carries any surplus.
  def business_profit_target(profit)
    target = @fiscal_year.business_profit_target
    unless target
      p(class: "mt-4 text-sm") { a(href: edit_fiscal_year_path(@fiscal_year), class: LINK) { "目標を設定 →" } }
      return
    end

    progress = @fiscal_year.business_profit_progress(profit)
    reached = profit >= target
    div(id: "business-profit-target", class: "mt-5") do
      div(class: "flex items-baseline justify-between gap-3 text-sm") do
        span(class: "text-muted") do
          plain "目標 (Target) "
          span(class: "ml-1 font-semibold tabular-nums text-ink") { yen(target) }
        end
        span(class: "font-semibold tabular-nums text-ink") { "#{progress}%" }
      end
      div(class: "mt-2 h-3 w-full rounded-full bg-primary-soft", role: "meter", aria_label: "事業利益の目標達成率",
          aria_valuemin: 0, aria_valuemax: 100, aria_valuenow: [ progress, 100 ].min, aria_valuetext: "#{progress}%") do
        div(class: "h-3 rounded-full bg-primary", style: "width: #{[ progress, 100 ].min}%") if progress.positive?
      end
      div(class: "mt-2 flex items-baseline justify-between gap-3 text-sm") do
        if reached
          span(class: "font-medium text-positive") { "✓ 目標達成 (Reached)" }
          span(class: "tabular-nums text-muted") { "+#{yen(profit - target)}" } if profit > target
        else
          span(class: "text-muted") { "目標まであと (To go)" }
          span(class: "font-semibold tabular-nums text-ink") { yen(target - profit) }
        end
      end
      p(class: "mt-2 text-right text-xs") { a(href: edit_fiscal_year_path(@fiscal_year), class: LINK) { "目標を変更" } }
    end
  end

  # 複製: the new-revenue form filled in from this one, a month later, in that
  # month's fiscal year (none until that year has been started). It opens as an
  # inline row in the frame under the revenue.
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

  def section_header(title, &actions)
    div(class: "flex items-center justify-between gap-3 mb-4") do
      h2(class: "whitespace-nowrap text-base font-semibold text-ink") { title }
      div(class: "flex items-center gap-2", &actions)
    end
  end

  # Latest entries, each linking to its edit form (which comes back here), plus
  # 複製 where copy_path gives a path for the entry. Its inline row loads into
  # the empty frame under the entry. by_month heads each month's entries with
  # the month and what was spent in it (実額, from the cashflow months).
  def recent_entries(id:, records:, label:, edit_path:, empty:, copy_path: nil, by_month: false)
    if records.empty?
      p(class: "text-sm text-muted py-2") { empty }
      return
    end

    ul(id: id, class: "divide-y divide-line border-t border-line") do
      records.each_with_index do |record, index|
        copy = copy_path&.call(record)
        month_heading(record.date.month) if by_month && record.date.month != (index.zero? ? nil : records[index - 1].date.month)
        li do
          div(class: "flex items-center gap-3") do
            a(href: edit_path.(record), class: "flex min-w-0 flex-1 items-baseline gap-3 py-2 px-2 -mx-2 rounded-md text-sm hover:bg-sunken") do
              span(class: "w-12 shrink-0 tabular-nums text-subtle") { record.date.strftime("%m/%d") }
              span(class: "min-w-0 flex-1 truncate text-ink") { record.public_send(label) }
              span(class: "tabular-nums text-ink") { yen(record.amount) }
            end
            if copy
              a(href: copy, title: "翌月分として複製", data: { turbo_frame: Views::Revenues::CopyRow.frame_id(record) },
                class: "shrink-0 text-xs #{LINK}") { "複製" }
            end
          end
          turbo_frame(id: Views::Revenues::CopyRow.frame_id(record), class: "block") if copy
        end
      end
    end
  end

  def month_heading(month)
    li(class: "flex items-baseline justify-between gap-3 bg-sunken px-2 py-1 -mx-2 text-xs text-muted") do
      span(class: "font-semibold text-ink") { "#{month}月" }
      span(class: "tabular-nums") { "支出 #{yen(@months[month - 1].expense)}" }
    end
  end

  def list_link(path)
    div(class: "mt-3 text-right") do
      a(href: path, class: "text-sm #{LINK}") { "一覧 →" }
    end
  end

  # The once-a-year sections: one line with the key figure and a single link.
  def summary_card(title, detail:, link_text:, link_path:, value: nil)
    div(class: "bg-surface rounded-lg border border-line px-5 py-4 flex items-center justify-between gap-4") do
      div(class: "min-w-0") do
        p(class: "text-sm font-medium text-muted") { title }
        p(class: "text-lg font-semibold tabular-nums text-ink") { value } if value
        p(class: "text-xs text-muted truncate") { detail }
      end
      a(href: link_path, class: "shrink-0 text-sm #{LINK}") { link_text }
    end
  end

  def yen(amount) = "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"
end

# frozen_string_literal: true

class JournalEntrySync
  # Maps Expense categories to Account codes
  CATEGORY_ACCOUNT_MAP = {
    "equipment" => "504",       # 消耗品費
    "office" => "505",          # 地代家賃
    "communication" => "503",   # 通信費
    "software" => "504",        # 消耗品費
    "transportation" => "502",  # 旅費交通費
    "books" => "507",           # 新聞図書費
    "other" => "510"            # 雑費
  }.freeze

  def self.sync(source)
    new(source).sync
  end

  def self.destroy(source)
    JournalEntry.find_by(source: source)&.destroy
  end

  def initialize(source)
    @source = source
  end

  def sync
    entry = JournalEntry.find_or_initialize_by(source: @source)
    entry.fiscal_year = @source.fiscal_year
    entry.date = @source.date
    entry.description = build_description

    entry.lines.destroy_all if entry.persisted?

    build_lines(entry)
    entry.save!
    entry
  end

  private

  def build_description
    case @source
    when Revenue
      "売上: #{@source.client_name}"
    when Expense
      "経費: #{@source.description}"
    end
  end

  def build_lines(entry)
    case @source
    when Revenue
      build_revenue_lines(entry)
    when Expense
      build_expense_lines(entry)
    end
  end

  def build_revenue_lines(entry)
    amount = @source.amount

    # 借方: 売掛金  / 貸方: 売上高
    entry.lines.build(account: find_account("103"), side: :debit, amount: amount)
    entry.lines.build(account: find_account("401"), side: :credit, amount: amount)
  end

  def build_expense_lines(entry)
    amount = @source.amount
    deductible = @source.deductible_amount
    personal = amount - deductible
    expense_account_code = CATEGORY_ACCOUNT_MAP[@source.category]

    # 借方: 経費勘定
    entry.lines.build(account: find_account(expense_account_code), side: :debit, amount: deductible)

    # 借方: 事業主貸 (personal portion, if any)
    if personal > 0
      entry.lines.build(account: find_account("190"), side: :debit, amount: personal)
    end

    # 貸方: 普通預金
    entry.lines.build(account: find_account("102"), side: :credit, amount: amount)
  end

  def find_account(code)
    Account.find_by!(code: code)
  end
end

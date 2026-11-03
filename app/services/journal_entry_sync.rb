# frozen_string_literal: true

# Posts the journal entries for a revenue or an expense, replacing any it had.
# Assets spread over several years get one entry when bought and one 減価償却
# entry at the end of each year, in every fiscal year that exists so far
# (FiscalYear adds its own when it's created later).
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

  BANK = "102"            # 普通預金
  RECEIVABLE = "103"      # 売掛金
  EQUIPMENT = "150"       # 工具器具備品
  LUMP_SUM = "151"        # 一括償却資産
  SOFTWARE = "152"        # ソフトウェア
  OWNER_DRAWINGS = "190"  # 事業主貸
  SALES = "401"           # 売上高
  DEPRECIATION = "511"    # 減価償却費

  def self.sync(source)
    new(source).sync
  end

  def self.destroy(source)
    JournalEntry.where(source: source).destroy_all
  end

  def initialize(source)
    @source = source
  end

  def sync
    self.class.destroy(@source)
    case @source
    when Revenue then sync_revenue
    when Expense then sync_expense
    end
  end

  private

  def sync_revenue
    amount = @source.amount
    post(@source.fiscal_year, @source.date, "売上: #{@source.client_name}",
         debit: { RECEIVABLE => amount }, credit: { SALES => amount })
  end

  def sync_expense
    if @source.depreciable?
      sync_depreciable_asset
    elsif @source.small_asset_special?
      paid_in_full(DEPRECIATION, "少額減価償却資産")
    else
      paid_in_full(CATEGORY_ACCOUNT_MAP[@source.category], "経費")
    end
  end

  # Expensed when paid: the business share to the expense account, the private share to 事業主貸.
  def paid_in_full(account, label)
    deductible = @source.deductible_amount
    post(@source.fiscal_year, @source.date, "#{label}: #{@source.description}",
         debit: { account => deductible, OWNER_DRAWINGS => @source.amount - deductible }, credit: { BANK => @source.amount })
  end

  def sync_depreciable_asset
    account = asset_account
    post(@source.fiscal_year, @source.date, "資産の取得: #{@source.description}",
         debit: { account => @source.amount }, credit: { BANK => @source.amount })

    @source.write_off_schedule.each do |year, charge|
      fiscal_year = FiscalYear.find_by(year: year) or next
      business = charge * @source.business_ratio / 100
      post(fiscal_year, Date.new(year, 12, 31), "減価償却: #{@source.description}",
           debit: { DEPRECIATION => business, OWNER_DRAWINGS => charge - business }, credit: { account => charge })
    end
  end

  def asset_account
    return LUMP_SUM if @source.lump_sum_3_year?

    @source.software? ? SOFTWARE : EQUIPMENT
  end

  # Zero amounts (e.g. no private share) get no line.
  def post(fiscal_year, date, description, debit:, credit:)
    entry = JournalEntry.new(source: @source, fiscal_year: fiscal_year, date: date, description: description)
    { debit: debit, credit: credit }.each do |side, amounts|
      amounts.each do |code, amount|
        entry.lines.build(account: find_account(code), side: side, amount: amount) if amount.positive?
      end
    end
    entry.save!
  end

  def find_account(code)
    Account.find_by!(code: code)
  end
end

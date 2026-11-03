# frozen_string_literal: true

require "test_helper"

class RevenueImportTest < ActiveSupport::TestCase
  setup do
    @fiscal_year = FiscalYear.create!(year: 2030)
    @tmpdir = Dir.mktmpdir
  end

  teardown do
    FileUtils.remove_entry(@tmpdir)
  end

  test "reads the usual ways of writing dates and amounts" do
    import = RevenueImport.new(<<~CSV)
      日付,取引先,金額
      2030-07-31,株式会社テックコープ,550000
      2030/8/31,株式会社テックコープ,"¥550,000"
      2030年9月15日,合同会社デザインラボ,２２０，０００円
    CSV

    assert_not import.errors?
    assert_equal [ [ 2, Date.new(2030, 7, 31), "株式会社テックコープ", 550_000 ],
                   [ 3, Date.new(2030, 8, 31), "株式会社テックコープ", 550_000 ],
                   [ 4, Date.new(2030, 9, 15), "合同会社デザインラボ", 220_000 ] ],
                 import.rows.map { |row| [ row.line, row.date, row.client_name, row.amount ] }
    assert import.rows.all? { |row| row.status == :new && row.fiscal_year == @fiscal_year }
  end

  test "accepts alternative headers and ignores extra columns" do
    english = RevenueImport.new("Date,Memo,Client,Amount\n2030-07-31,7月分,Acme,110000\n")
    japanese = RevenueImport.new("日付,取引先名,金額（税込）\n2030-07-31,Acme,110000\n")

    [ english, japanese ].each do |import|
      assert_not import.errors?
      assert_equal [ "Acme", 110_000 ], [ import.rows.first.client_name, import.rows.first.amount ]
    end
  end

  test "reads Shift_JIS files, where Excel writes the yen sign as a backslash" do
    path = write_file("日付,取引先,金額\r\n2030/7/31,株式会社テックコープ,\"\\550,000\"\r\n".encode(Encoding::Windows_31J))
    import = RevenueImport.from_file(path)

    assert_not import.errors?
    assert_equal [ "株式会社テックコープ", 550_000 ], [ import.rows.first.client_name, import.rows.first.amount ]
  end

  test "reads UTF-8 files with a byte order mark" do
    path = write_file("\uFEFF日付,取引先,金額\n2030-07-31,Acme,1000\n")
    assert_not RevenueImport.from_file(path).errors?
  end

  test "skips blank rows but reports file line numbers" do
    import = RevenueImport.new("日付,取引先,金額\n\n2030-07-31,Acme,1000\n,,\n2030-08-31,Acme,2000\n")
    assert_equal [ 3, 5 ], import.rows.map(&:line)
  end

  test "a missing column is reported and no rows are read" do
    import = RevenueImport.new("日付,金額\n2030-07-31,1000\n")

    assert import.errors?
    assert_match "取引先", import.problems.first
    assert_empty import.rows
  end

  test "a file without data rows is an error" do
    assert RevenueImport.new("日付,取引先,金額\n").errors?
  end

  test "row errors say what is wrong on which line" do
    import = RevenueImport.new(<<~CSV)
      日付,取引先,金額
      2030-02-30,Acme,1000
      2030-07-31,,1000
      2030-07-31,Acme,1000.5
      2030-07-31,Acme,-1000
      2029-12-31,Acme,1000
    CSV

    assert import.errors?
    assert import.rows.all? { |row| row.status == :error }
    messages = import.rows.to_h { |row| [ row.line, row.message ] }
    assert_match "日付が読めません", messages[2]
    assert_match "取引先が空です", messages[3]
    assert_match "金額が読めません", messages[4]
    assert_match "金額が読めません", messages[5]
    assert_match "2029年の年度がありません", messages[6]
  end

  test "rows matching an existing revenue are skipped, so re-running a file is safe" do
    csv = "日付,取引先,金額\n2030-07-31,Acme,1000\n2030-08-31,Acme,2000\n"
    assert_equal 2, RevenueImport.new(csv).save!

    rerun = RevenueImport.new(csv)
    assert_equal [ :duplicate, :duplicate ], rerun.rows.map(&:status)
    assert_equal 0, rerun.save!
    assert_equal 2, @fiscal_year.revenues.count
  end

  test "each row is saved to the fiscal year of its date" do
    next_year = FiscalYear.create!(year: 2031)
    RevenueImport.new("日付,取引先,金額\n2030-12-31,Acme,1000\n2031-01-05,Acme,2000\n").save!

    assert_equal [ 1000 ], @fiscal_year.revenues.pluck(:amount)
    assert_equal [ 2000 ], next_year.revenues.pluck(:amount)
  end

  test "nothing is saved while any row has an error" do
    import = RevenueImport.new("日付,取引先,金額\n2030-07-31,Acme,1000\n2030-07-31,,2000\n")

    assert_raises(RevenueImport::Invalid) { import.save! }
    assert_equal 0, Revenue.count
  end

  test "identical rows within the file are all kept, with a warning" do
    import = RevenueImport.new("日付,取引先,金額\n2030-07-31,Acme,1000\n2030-07-31,Acme,1000\n")

    assert_equal [ :new, :new ], import.rows.map(&:status)
    assert_match "2行目・3行目", import.warnings.first
  end

  private

  def write_file(content)
    File.join(@tmpdir, "revenues.csv").tap { |path| File.binwrite(path, content) }
  end
end

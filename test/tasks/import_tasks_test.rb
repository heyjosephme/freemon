# frozen_string_literal: true

require "test_helper"
require "rake"

class ImportTasksTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("revenues:import")
    Rake::Task["revenues:import"].reenable
    Rake::Task["expenses:import"].reenable
    @fiscal_year = FiscalYear.create!(year: 2025)
  end

  teardown do
    ENV.delete("FILE")
    ENV.delete("COMMIT")
  end

  test "a revenue dry run lists the rows and saves nothing" do
    output = run_task("revenues:import", FILE: file_fixture("revenues.csv").to_s)

    assert_match "新規     2行目  2025-07-31      ¥550,000  株式会社テックコープ", output
    assert_match "2025年: 新規4件 ¥1,870,000", output
    assert_match "ドライラン", output
    assert_equal 0, Revenue.count
  end

  test "COMMIT=1 saves the revenues" do
    output = run_task("revenues:import", FILE: file_fixture("revenues.csv").to_s, COMMIT: "1")

    assert_match "4件の売上を保存しました。", output
    assert_equal 4, @fiscal_year.revenues.count
  end

  test "a file with errors aborts without saving anything" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "broken.csv")
      File.write(path, "日付,取引先,金額\n2025-07-31,Acme,1000\n2025-07-31,,2000\n")

      output = run_task("revenues:import", FILE: path, COMMIT: "1", expect_exit: true)
      assert_match "エラー   3行目  取引先が空です", output
      assert_match "何も保存していません", output
    end
    assert_equal 0, Revenue.count
  end

  test "FILE is required" do
    assert_match "使い方: bin/rails expenses:import", run_task("expenses:import", expect_exit: true)
  end

  test "an expense dry run shows category, 按分 and the deductible total" do
    output = run_task("expenses:import", FILE: file_fixture("expenses.csv").to_s)

    assert_match "新規     2行目  2025-07-01      ¥298,000  MacBook Pro（備品・器具、按分80%、インボイスあり、オンライン）", output
    assert_match "新規     4行目  2025-08-15        ¥3,520  技術書（書籍・学習、按分100%）", output
    assert_match "2025年: 新規4件 ¥337,520（按分後 ¥274,920）", output
    assert_equal 0, Expense.count
  end

  test "COMMIT=1 saves the expenses" do
    output = run_task("expenses:import", FILE: file_fixture("expenses.csv").to_s, COMMIT: "1")

    assert_match "4件の経費を保存しました。", output
    assert_equal 274_920, @fiscal_year.reload.total_expenses
  end

  private

  def run_task(name, expect_exit: false, **env)
    env.each { |key, value| ENV[key.to_s] = value }
    out, err = capture_io do
      if expect_exit
        error = assert_raises(SystemExit) { Rake::Task[name].invoke }
        assert_not error.success?
      else
        Rake::Task[name].invoke
      end
    end
    out + err
  end
end

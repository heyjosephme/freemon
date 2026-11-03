# frozen_string_literal: true

require "test_helper"
require "rake"

class RevenuesImportTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("revenues:import")
    @task = Rake::Task["revenues:import"]
    @task.reenable
    @fiscal_year = FiscalYear.create!(year: 2025)
  end

  teardown do
    ENV.delete("FILE")
    ENV.delete("COMMIT")
  end

  test "a dry run lists the rows and saves nothing" do
    output = run_task(FILE: file_fixture("revenues.csv").to_s)

    assert_match "新規     2行目  2025-07-31      ¥550,000  株式会社テックコープ", output
    assert_match "2025年: 新規4件 ¥1,870,000", output
    assert_match "ドライラン", output
    assert_equal 0, Revenue.count
  end

  test "COMMIT=1 saves the rows" do
    output = run_task(FILE: file_fixture("revenues.csv").to_s, COMMIT: "1")

    assert_match "4件の売上を保存しました。", output
    assert_equal 4, @fiscal_year.revenues.count
  end

  test "a file with errors aborts without saving anything" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "broken.csv")
      File.write(path, "日付,取引先,金額\n2025-07-31,Acme,1000\n2025-07-31,,2000\n")

      output = run_task(FILE: path, COMMIT: "1", expect_exit: true)
      assert_match "エラー   3行目  取引先が空です", output
      assert_match "何も保存していません", output
    end
    assert_equal 0, Revenue.count
  end

  test "FILE is required" do
    assert_match "使い方", run_task(expect_exit: true)
  end

  private

  def run_task(expect_exit: false, **env)
    env.each { |key, value| ENV[key.to_s] = value }
    out, err = capture_io do
      if expect_exit
        error = assert_raises(SystemExit) { @task.invoke }
        assert_not error.success?
      else
        @task.invoke
      end
    end
    out + err
  end
end

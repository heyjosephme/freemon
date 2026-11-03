# frozen_string_literal: true

require "test_helper"

class CurrentYearTest < ActionDispatch::IntegrationTest
  test "the home page opens this year's dashboard" do
    travel_to Date.new(2031, 6, 1) do
      FiscalYear.create!(year: 2030)
      current = FiscalYear.create!(year: 2031)

      get root_url
      assert_redirected_to fiscal_year_url(current)
    end
  end

  test "the year turns over at midnight Japan time" do
    travel_to Time.utc(2030, 12, 31, 15, 30) do # 2031-01-01 00:30 JST
      FiscalYear.create!(year: 2030)
      current = FiscalYear.create!(year: 2031)

      get root_url
      assert_redirected_to fiscal_year_url(current)
    end
  end

  test "without this year's record it opens the latest earlier year, which offers to start one" do
    travel_to Date.new(2031, 6, 1) do
      FiscalYear.create!(year: 2029)
      latest = FiscalYear.create!(year: 2030, filing_type: :white)

      get root_url
      assert_redirected_to fiscal_year_url(latest)

      follow_redirect!
      assert_select "form[action='#{fiscal_years_path}']" do
        assert_select "input[type=hidden][name='fiscal_year[year]'][value='2031']"
        assert_select "input[type=hidden][name='fiscal_year[filing_type]'][value='white']"
        assert_select "button", text: "2031年の帳簿を始める"
      end
    end
  end

  test "with no fiscal years at all it goes to the create form" do
    get root_url
    assert_redirected_to new_fiscal_year_url
  end

  test "from January to March the open filing is linked from this year's and last year's dashboards" do
    travel_to Date.new(2031, 2, 1) do
      previous = FiscalYear.create!(year: 2030)
      current = FiscalYear.create!(year: 2031)

      [ current, previous ].each do |fiscal_year|
        get fiscal_year_url(fiscal_year)
        assert_select "a[href='#{tax_summary_fiscal_year_path(previous)}']", text: /2030年分の確定申告/
        assert_match "所得税 3/15まで・消費税 3/31まで", response.body
      end
    end
  end

  test "no filing reminder after March" do
    travel_to Date.new(2031, 4, 1) do
      FiscalYear.create!(year: 2030)
      current = FiscalYear.create!(year: 2031)

      get fiscal_year_url(current)
      assert_no_match "年分の確定申告", response.body
    end
  end

  test "the create form suggests this year and the latest filing type" do
    travel_to Date.new(2031, 6, 1) do
      FiscalYear.create!(year: 2030, filing_type: :blue_10)

      get new_fiscal_year_url
      assert_select "input[name='fiscal_year[year]'][value='2031']"
      assert_select "input[type=radio][value='blue_10'][checked]"
    end
  end

  test "once this year exists the create form suggests the most recent missing earlier year" do
    travel_to Date.new(2031, 6, 1) do
      FiscalYear.create!(year: 2031)
      FiscalYear.create!(year: 2030)

      get new_fiscal_year_url
      assert_select "input[name='fiscal_year[year]'][value='2029']"
    end
  end

  test "the navbar lists every year and the year list" do
    older = FiscalYear.create!(year: 2030)
    newer = FiscalYear.create!(year: 2031)

    get fiscal_year_url(older)
    assert_select "nav details summary", text: /2030年/
    assert_select "nav details a[href='#{fiscal_year_path(newer)}']", text: "2031年"
    assert_select "nav details a[href='#{fiscal_years_path}']", text: "すべての年度"
  end
end

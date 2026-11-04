# frozen_string_literal: true

require "test_helper"

class RevenueCopyTest < ActionDispatch::IntegrationTest
  setup do
    @fiscal_year = FiscalYear.create!(year: 2030)
    @revenue = @fiscal_year.revenues.create!(client_name: "株式会社テックコープ", amount: 550_000, date: Date.new(2030, 9, 30))
  end

  test "複製 on the dashboard loads a row filled in with the same client and amount, a month later, into the frame under it" do
    get fiscal_year_url(@fiscal_year)
    copy = new_fiscal_year_revenue_path(@fiscal_year, from_revenue: @revenue.id, return_to: "dashboard")
    assert_select "#recent-revenues a[href=?][data-turbo-frame=?]", copy, frame, text: "複製"
    assert_select "#recent-revenues turbo-frame##{frame}:empty"

    assert_no_difference -> { Revenue.count } do
      get copy, headers: { "Turbo-Frame" => frame }
    end
    assert_select "nav", count: 0, message: "a frame request skips the layout"
    assert_select "turbo-frame##{frame} form[action=?][data-turbo-frame=_top]", fiscal_year_revenues_path(@fiscal_year) do
      assert_select "input[name='revenue[client_name]'][value=?]", "株式会社テックコープ"
      assert_select "input[name='revenue[amount]'][value='550000'][autofocus]"
      assert_select "input[name='revenue[date]'][value='2030-10-31']"
      assert_select "input[name=return_to][value=dashboard]"
    end
  end

  test "without a frame, 複製 opens the full form filled in" do
    get new_fiscal_year_revenue_path(@fiscal_year, from_revenue: @revenue.id)

    assert_select "h1", text: "売上の追加"
    assert_select "input[name='revenue[client_name]'][value=?]", "株式会社テックコープ"
    assert_select "input[name='revenue[date]'][value='2030-10-31']"
  end

  test "the revenue list offers 複製 too, with a hidden row for the frame" do
    get fiscal_year_revenues_url(@fiscal_year)

    assert_select "a[href=?][data-turbo-frame=?]", new_fiscal_year_revenue_path(@fiscal_year, from_revenue: @revenue.id), frame, text: "複製"
    assert_select "tr[class*='turbo-frame:empty'] td[colspan='5'] turbo-frame##{frame}:empty"
  end

  test "December's copy goes into next year once that year has been started" do
    december = @fiscal_year.revenues.create!(client_name: "合同会社デザインラボ", amount: 220_000, date: Date.new(2030, 12, 31))

    get fiscal_year_revenues_url(@fiscal_year)
    assert_select "a[href*='from_revenue=#{december.id}']", count: 0

    following = FiscalYear.create!(year: 2031)
    get fiscal_year_revenues_url(@fiscal_year)
    assert_select "a[href=?]", new_fiscal_year_revenue_path(following, from_revenue: december.id), text: "複製"
  end

  test "a new year without revenue points to last year's list to copy from" do
    following = FiscalYear.create!(year: 2031)

    get fiscal_year_url(following)
    assert_select "a[href=?]", fiscal_year_revenues_path(@fiscal_year), text: "2030年の一覧"
  end

  private

  def frame = "copy_revenue_#{@revenue.id}"
end

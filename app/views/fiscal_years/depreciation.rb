# frozen_string_literal: true

# A year's 減価償却費の計算, laid out like the table in the 青色申告決算書.
class Views::FiscalYears::Depreciation < Views::Base
  METHOD_LABELS = {
    "normal_depreciation" => "定額法",
    "lump_sum_3_year" => "一括償却",
    "small_asset_special" => "少額特例"
  }.freeze

  def initialize(fiscal_year:, assets:)
    @fiscal_year = fiscal_year
    @assets = assets
    @year = fiscal_year.year
  end

  def view_template
    render PageHeader.new(title: "#{@year}年 減価償却費の計算 (Depreciation)", back_path: fiscal_year_path(@fiscal_year))

    if @assets.empty?
      render EmptyState.new(
        message: "この年に償却する資産はありません。設備・資産は経費として登録できます。",
        action_text: "経費一覧へ",
        action_path: fiscal_year_expenses_path(@fiscal_year)
      )
      return
    end

    render Card.new do
      div(class: "overflow-x-auto") do
        table(class: "min-w-full divide-y divide-gray-200") do
          thead { header_row }
          tbody(class: "divide-y divide-gray-100") { @assets.each { |asset| asset_row(asset) } }
          tfoot { totals_row }
        end
      end
      p(class: "mt-4 text-xs text-gray-500") do
        "少額特例 = 少額減価償却資産の特例（措法28条の2、年300万円まで）。一括償却 = 一括償却資産（3年均等）。定額法は取得月から月割りで、最後に1円を残します。"
      end
    end
  end

  private

  def header_row
    tr do
      th(class: th_classes) { "名称" }
      th(class: th_classes) { "取得年月" }
      th(class: "#{th_classes} text-right") { "取得価額" }
      th(class: th_classes) { "償却方法" }
      th(class: "#{th_classes} text-right") { "耐用年数" }
      th(class: "#{th_classes} text-right") { "償却率" }
      th(class: "#{th_classes} text-right") { "本年中の償却期間" }
      th(class: "#{th_classes} text-right") { "本年分の償却費" }
      th(class: "#{th_classes} text-right") { "事業専用割合" }
      th(class: "#{th_classes} text-right") { "本年分の必要経費算入額" }
      th(class: "#{th_classes} text-right") { "未償却残高（期末）" }
    end
  end

  def asset_row(asset)
    tr do
      td(class: td_classes) { asset.description }
      td(class: td_classes) { "#{asset.date.year}年#{asset.date.month}月" }
      td(class: number_classes) { yen(asset.amount) }
      td(class: td_classes) { METHOD_LABELS[asset.accounting_method] }
      td(class: number_classes) { asset.normal_depreciation? ? "#{asset.useful_life}年" : "—" }
      td(class: number_classes) { rate(asset) }
      td(class: number_classes) { asset.normal_depreciation? ? "#{asset.months_in_service(@year)}/12" : "—" }
      td(class: number_classes) { yen(charge(asset)) }
      td(class: number_classes) { "#{asset.business_ratio}%" }
      td(class: number_classes) { yen(asset.deduction_for(@year)) }
      td(class: number_classes) { yen(asset.book_value_after(@year)) }
    end
  end

  def totals_row
    tr(class: "bg-gray-50 font-semibold") do
      td(class: td_classes, colspan: 7) { "合計" }
      td(class: number_classes) { yen(@assets.sum { |asset| charge(asset) }) }
      td { "" }
      td(class: number_classes) { yen(@assets.sum { |asset| asset.deduction_for(@year) }) }
      td(class: number_classes) { yen(@assets.sum { |asset| asset.book_value_after(@year) }) }
    end
  end

  def charge(asset) = asset.write_off_schedule.fetch(@year, 0)

  def rate(asset)
    if asset.normal_depreciation? then Kernel.format("0.%03d", asset.depreciation_rate) # Phlex views have their own #format
    elsif asset.lump_sum_3_year? then "1/3"
    else "—"
    end
  end

  def yen(amount) = "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"

  def th_classes = "px-3 py-3 text-left text-xs font-medium text-gray-500 whitespace-nowrap"

  def td_classes = "px-3 py-3 text-sm text-gray-900 whitespace-nowrap"

  def number_classes = "#{td_classes} text-right tabular-nums"
end

# frozen_string_literal: true

# 償却資産税の概算: the 償却資産申告 due in the January after the fiscal year, asset by asset.
class Views::FiscalYears::FixedAssetTax < Views::Base
  METHOD_LABELS = Views::FiscalYears::Depreciation::METHOD_LABELS

  def initialize(fiscal_year:, estimate:)
    @fiscal_year = fiscal_year
    @estimate = estimate
  end

  def view_template
    render PageHeader.new(title: "#{@estimate[:tax_year]}年度 償却資産税 (Fixed asset tax)", back_path: fiscal_year_path(@fiscal_year)) do
      render Button.new(href: depreciation_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "減価償却" }
    end
    render Disclaimer.new

    if @estimate[:rows].empty? && @estimate[:unvalued].empty?
      render EmptyState.new(
        message: "#{date(@estimate[:assessed_on])}時点で申告の対象になる資産はありません。10万円未満の資産、一括償却資産、ソフトウェアは対象外です。",
        action_text: "経費一覧へ",
        action_path: fiscal_year_expenses_path(@fiscal_year)
      )
      return
    end

    unvalued_warning if @estimate[:unvalued].any?
    summary
    div(class: "mt-6") { asset_table } if @estimate[:rows].any?
    div(class: "mt-6") { notes }
  end

  private

  def summary
    render Card.new do
      div(class: "text-center py-2") do
        h2(class: "text-sm font-semibold text-muted mb-2") { "#{@estimate[:tax_year]}年度の税額の目安 (Estimated tax)" }
        p(class: "font-display font-semibold tabular-nums text-4xl text-primary") { yen(@estimate[:tax]) }
        p(class: "text-sm text-muted mt-3") { verdict }
      end
      div(class: "mt-4") do
        render SummaryRow.new(label: "取得価額の合計", value: @estimate[:total_cost])
        render SummaryRow.new(label: "評価額の合計", value: @estimate[:total_value])
        render SummaryRow.new(label: "課税標準額（千円未満切捨て）", value: @estimate[:tax_base])
        render SummaryRow.new(label: "免税点（課税標準額がこれ未満なら課税なし）", value: @estimate[:exemption_point])
        render SummaryRow.new(label: "税額（課税標準額 × 1.4%、百円未満切捨て）", value: @estimate[:tax], highlight: true)
      end
      p(class: "text-xs text-muted mt-3") do
        "#{date(@estimate[:assessed_on])}現在の資産を、#{date(@estimate[:declare_by])}までに資産のある市区町村（東京23区は都税事務所）へ申告します。免税点未満でも申告は必要です。"
      end
    end
  end

  def verdict
    if @estimate[:exempt]
      "課税標準額が免税点 #{yen(@estimate[:exemption_point])} 未満なので、課税されない見込みです。"
    else
      "納付は年4回（東京23区は6月・9月・12月・翌年2月）。納めた税額は租税公課として経費にできます（家事按分後）。"
    end
  end

  def unvalued_warning
    div(class: "bg-warning-soft border border-warning-line rounded-md p-4 mb-6") do
      p(class: "text-sm text-warning") do
        strong { "耐用年数が未入力の資産があります。" }
        plain "評価額を計算できないため、下の合計には含まれていません。耐用年数を入力してください: "
        @estimate[:unvalued].each_with_index do |asset, index|
          plain "、" if index.positive?
          a(href: edit_fiscal_year_expense_path(asset.fiscal_year_id, asset), class: "underline underline-offset-4") do
            "#{asset.description}（#{yen(asset.amount)}）"
          end
        end
      end
    end
  end

  def asset_table
    render Card.new(title: "申告の対象になる資産 (Declared assets)") do
      div(class: "overflow-x-auto") do
        table(class: "min-w-full divide-y divide-line") do
          thead do
            tr do
              th(class: th_classes) { "名称" }
              th(class: th_classes) { "取得年月" }
              th(class: "#{th_classes} text-right") { "取得価額" }
              th(class: th_classes) { "所得税の償却方法" }
              th(class: "#{th_classes} text-right") { "耐用年数" }
              th(class: "#{th_classes} text-right") { "減価率" }
              th(class: "#{th_classes} text-right") { "評価額" }
            end
          end
          tbody(class: "divide-y divide-line") { @estimate[:rows].each { |row| asset_row(row) } }
          tfoot do
            tr(class: "bg-sunken font-semibold") do
              td(class: td_classes, colspan: 2) { "合計" }
              td(class: number_classes) { yen(@estimate[:total_cost]) }
              td(colspan: 3) { "" }
              td(class: number_classes) { yen(@estimate[:total_value]) }
            end
          end
        end
      end
    end
  end

  def asset_row(row)
    asset = row.asset
    tr do
      td(class: td_classes) { asset.description }
      td(class: td_classes) { "#{asset.date.year}年#{asset.date.month}月" }
      td(class: number_classes) { yen(asset.amount) }
      td(class: td_classes) { METHOD_LABELS[asset.accounting_method] }
      td(class: number_classes) { "#{asset.useful_life}年" }
      td(class: number_classes) { Kernel.format("0.%03d", row.rate) } # Phlex views have their own #format
      td(class: number_classes) do
        plain yen(row.value)
        span(class: "ml-1 text-xs text-muted") { "（5%）" } if row.floored?
      end
    end
  end

  def notes
    render Card.new(title: "前提・注意 (Assumptions)") do
      ul(class: "list-disc list-inside text-sm text-muted space-y-1") do
        li { "対象は「設備・資産」のうち、少額減価償却資産の特例と定額法のもの。10万円未満で全額経費にした資産、一括償却資産、ソフトウェアは対象外です。" }
        li { "少額減価償却資産の特例で全額経費にした資産も、償却資産税では耐用年数に沿って評価されます。10〜20万円未満なら一括償却資産にすると対象外になります。" }
        li { "評価額 = 取得価額 ×（1 − 減価率 ÷ 2）、翌年度からは前年度の評価額 ×（1 − 減価率）。取得価額の5%が下限です。家事按分前の取得価額（税込経理）で評価します。" }
        li { "免税点は2027年度から180万円（2026年度までは150万円）。税率は標準の1.4%です。" }
        li { "資産はすべて同じ市区町村にあるものとして計算します。売却・廃棄した資産や、自動車税のかかる車は対象外なので、該当するものは差し引いてください。" }
        li { "納税準備の目安には含まれていません。" }
      end
    end
  end

  def date(day) = "#{day.year}年#{day.month}月#{day.day}日"

  def yen(amount) = "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"

  def th_classes = "px-3 py-3 text-left text-xs font-medium text-muted whitespace-nowrap"

  def td_classes = "px-3 py-3 text-sm tabular-nums text-ink whitespace-nowrap"

  def number_classes = "#{td_classes} text-right tabular-nums"
end

# frozen_string_literal: true

class Views::FiscalYears::TaxSaving < Views::Base
  def initialize(fiscal_year:, simulation:)
    @fiscal_year = fiscal_year
    @sim = simulation
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年 節税シミュレーション (Tax-Saving)", back_path: fiscal_year_path(@fiscal_year)) do
      render Button.new(href: tax_reserve_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "納税準備" }
      render Button.new(href: tax_summary_fiscal_year_path(@fiscal_year), size: :sm) { "税額計算" }
    end
    render Disclaimer.new

    marginal_hero

    if @sim[:taxable_income].zero?
      div(class: "bg-blue-50 border border-blue-200 rounded-md p-4") do
        p(class: "text-sm text-blue-800") { "現在の課税所得は¥0です。所得が発生すると、各制度による節税効果がここに表示されます。" }
      end
      return
    end

    div(class: "mt-6 grid grid-cols-1 gap-6") do
      @sim[:results].each { |result| instrument_card(result) }
    end
  end

  private

  def marginal_hero
    pct = (@sim[:marginal_rate] * 100).round(1)
    income_pct = (@sim[:income_marginal_rate] * 100).round.to_i
    render Card.new do
      div(class: "text-center py-2") do
        h2(class: "text-sm font-semibold text-gray-500 uppercase mb-2") { "あなたの限界税率 (Marginal Tax Rate)" }
        p(class: "text-4xl font-bold text-indigo-700") { "#{pct}%" }
        p(class: "text-sm text-gray-500 mt-2") do
          "課税所得を1円減らすごとに、所得税＋住民税が約#{pct}%軽減されます（所得税#{income_pct}% + 復興税 + 住民税10%）。"
        end
      end
    end
  end

  def instrument_card(result)
    render Card.new(title: result.instrument.name) do
      p(class: "text-sm text-gray-500 mb-4") { result.instrument.note }
      div(class: "space-y-1") do
        result.scenarios.each { |scenario| scenario_row(scenario) }
      end
    end
  end

  def scenario_row(scenario)
    div(class: "flex items-center justify-between py-2 border-b border-gray-100") do
      div(class: "flex items-center gap-2") do
        div do
          p(class: "text-sm text-gray-700") { "月 #{yen(scenario.monthly)}" }
          p(class: "text-xs text-gray-400") { "年 #{yen(scenario.annual)}" }
        end
        render Badge.new(text: "上限", color: :indigo) if scenario.at_max
      end
      div(class: "text-right") do
        p(class: "text-base font-bold text-emerald-600") { "−#{yen(scenario.savings)}" }
        p(class: "text-xs text-gray-400") { "実質 #{scenario.effective_rate}% 還元" }
      end
    end
  end

  def yen(amount)
    "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"
  end
end

# frozen_string_literal: true

class Views::FiscalYears::TaxReserve < Views::Base
  METHOD_LABELS = {
    standard: "本則課税",
    simplified: "簡易課税",
    special: "2割特例"
  }.freeze

  def initialize(fiscal_year:, reserve:)
    @fiscal_year = fiscal_year
    @reserve = reserve
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年 納税準備 (Tax Reserve)", back_path: fiscal_year_path(@fiscal_year)) do
      render Button.new(href: cashflow_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "キャッシュフロー" }
      render Button.new(href: tax_summary_fiscal_year_path(@fiscal_year), size: :sm) { "税額計算" }
    end
    render Disclaimer.new

    hero
    div(class: "mt-6") { breakdown }
    div(class: "mt-6") { notes }
  end

  private

  def hero
    render Card.new do
      div(class: "text-center py-2") do
        h2(class: "text-sm font-semibold text-gray-500 uppercase mb-2") { "納税準備の目安 (Recommended Reserve)" }
        p(class: "text-4xl font-bold text-indigo-700") { yen(@reserve[:total]) }
        if @reserve[:revenue].positive?
          p(class: "text-sm text-gray-500 mt-3") do
            plain "売上の約 "
            span(class: "font-semibold text-gray-700") { "#{@reserve[:reserve_rate]}%" }
            plain " ／ 毎月の積立目安 約 "
            span(class: "font-semibold text-gray-700") { yen(@reserve[:monthly]) }
          end
        end
      end
    end
  end

  def breakdown
    render Card.new(title: "内訳 (Breakdown)") do
      @reserve[:components].each do |component|
        div(class: "flex justify-between items-center py-3 border-b border-gray-100") do
          div do
            p(class: "text-sm text-gray-700") { component.label }
            p(class: "text-xs text-gray-400 mt-0.5") { "納付時期: #{component.timing}" }
          end
          render MoneyDisplay.new(amount: component.amount)
        end
      end

      div(class: "flex justify-between items-center pt-3 mt-2 border-t-2 border-gray-900") do
        span(class: "text-base font-bold text-gray-900") { "合計 (Total)" }
        render MoneyDisplay.new(amount: @reserve[:total], size: :lg)
      end

      p(class: "text-xs text-gray-500 mt-3") do
        plain "※ 消費税は#{METHOD_LABELS[@reserve[:recommended_consumption_method]]}（最も有利な方式）で計算しています。"
      end
    end
  end

  def notes
    render Card.new(title: "前提・注意 (Assumptions)") do
      ul(class: "list-disc list-inside text-sm text-gray-600 space-y-1") do
        li { "住民税は所得割10% + 均等割¥5,000、基礎控除¥430,000での概算です（自治体により異なります）。" }
        li { "国民健康保険は東京23区の標準的な料率による概算です。介護分（40〜64歳）は含みません。" }
        li { "前年実績に基づく予定納税（所得税・消費税の中間納付）は含みません。" }
        li { "所得税は源泉徴収税額を差し引いた納付見込額です。" }
      end
    end
  end

  def yen(amount)
    "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"
  end
end

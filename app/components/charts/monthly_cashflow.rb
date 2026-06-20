# frozen_string_literal: true

# Server-rendered SVG chart: 12 months of revenue/expense columns plus a
# cumulative-balance line. No JS. Input is an array of CashflowReport::Month.
#
# Bars share one scale (max of any month's revenue/expense). The cumulative
# line uses its own scale (a trend line) — its end value equals the period's
# net, which the surrounding view shows numerically.
class Components::Charts::MonthlyCashflow < Phlex::SVG
  VB_W = 720.0
  VB_H = 300.0
  PAD_L = 10.0
  PAD_R = 10.0
  PAD_T = 12.0
  PAD_B = 24.0

  REVENUE_COLOR = "#4f46e5"    # indigo-600
  EXPENSE_COLOR = "#e11d48"    # rose-600
  CUMULATIVE_COLOR = "#059669" # emerald-600

  def initialize(months:)
    @months = months
  end

  def view_template
    svg(viewBox: "0 0 #{VB_W.to_i} #{VB_H.to_i}", class: "w-full h-auto", role: "img",
        aria_label: "月次キャッシュフロー") do
      line(x1: PAD_L, y1: baseline_y, x2: VB_W - PAD_R, y2: baseline_y, stroke: "#d1d5db", stroke_width: "1")

      @months.each_with_index do |m, i|
        c = center_x(i)
        draw_bar(c - gap / 2 - bar_w, m.revenue, REVENUE_COLOR)
        draw_bar(c + gap / 2, m.expense, EXPENSE_COLOR)
        text(x: c.round(2), y: (baseline_y + 16).round(2), fill: "#9ca3af",
             font_size: "11", text_anchor: "middle") { (i + 1).to_s }
      end

      polyline(points: cumulative_points, fill: "none", stroke: CUMULATIVE_COLOR,
               stroke_width: "2", stroke_linejoin: "round", stroke_linecap: "round")
      circle(cx: center_x(@months.length - 1).round(2),
             cy: cumulative_y(@months.last.cumulative).round(2), r: "3.5", fill: CUMULATIVE_COLOR)
    end
  end

  private

  def draw_bar(x, value, color)
    h = bar_height(value)
    return if h <= 0

    rect(x: x.round(2), y: (baseline_y - h).round(2), width: bar_w.round(2),
         height: h.round(2), fill: color, rx: "1")
  end

  def plot_w = VB_W - PAD_L - PAD_R
  def plot_h = VB_H - PAD_T - PAD_B
  def baseline_y = PAD_T + plot_h
  def slot_w = plot_w / 12.0
  def usable_h = plot_h * 0.88
  def bar_w = slot_w * 0.30
  def gap = slot_w * 0.07
  def center_x(index) = PAD_L + slot_w * index + slot_w / 2.0

  def bar_max
    @bar_max ||= [ @months.flat_map { |m| [ m.revenue, m.expense ] }.max, 1 ].max
  end

  def bar_height(value) = (value.to_f / bar_max) * usable_h

  def cumulative_range
    @cumulative_range ||= begin
      cums = @months.map(&:cumulative)
      span = cums.max - cums.min
      [ cums.min, span.zero? ? 1 : span ]
    end
  end

  def cumulative_y(value)
    min, span = cumulative_range
    baseline_y - ((value - min).to_f / span) * usable_h
  end

  def cumulative_points
    @months.each_with_index
           .map { |m, i| "#{center_x(i).round(2)},#{cumulative_y(m.cumulative).round(2)}" }
           .join(" ")
  end
end

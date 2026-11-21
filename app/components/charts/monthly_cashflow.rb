# frozen_string_literal: true

# Server-rendered SVG chart: 12 months of revenue/expense columns plus a
# cumulative-balance line. No JS. Input is an array of CashflowReport::Month.
#
# Bars share one scale (max of any month's revenue/expense). The cumulative
# line uses its own scale (a trend line) — its end value equals the period's
# net, which the surrounding view shows numerically.
#
# The dashboard draws a shorter one without the line (height:, cumulative: false)
# and marks the month in progress (current_month:, 1–12).
class Components::Charts::MonthlyCashflow < Phlex::SVG
  VB_W = 720.0
  PAD_L = 10.0
  PAD_R = 10.0
  PAD_T = 12.0
  PAD_B = 24.0

  # Colour roles as Tailwind fill/stroke classes (var() doesn't work in SVG
  # presentation attributes). The cashflow page's legend uses the same roles.
  REVENUE_FILL = "fill-primary"
  EXPENSE_FILL = "fill-negative"

  def initialize(months:, height: 300, cumulative: true, current_month: nil)
    @months = months
    @height = height.to_f
    @cumulative = cumulative
    @current_month = current_month
  end

  def view_template
    svg(viewBox: "0 0 #{VB_W.to_i} #{@height.to_i}", class: "w-full h-auto", role: "img",
        aria_label: "月次キャッシュフロー") do
      @months.each_with_index do |m, i|
        c = center_x(i)
        current = m.month == @current_month
        if current
          rect(x: (c - slot_w / 2).round(2), y: 0, width: slot_w.round(2), height: @height, class: "fill-sunken", rx: "4")
        end
        draw_bar(c - gap / 2 - bar_w, m.revenue, REVENUE_FILL)
        draw_bar(c + gap / 2, m.expense, EXPENSE_FILL)
        text(x: c.round(2), y: (baseline_y + 17).round(2), class: current ? "fill-ink font-semibold" : "fill-subtle",
             font_size: label_size, text_anchor: "middle") { (i + 1).to_s }
      end

      # Drawn after the current month's band, so the band doesn't cover it.
      line(x1: PAD_L, y1: baseline_y, x2: VB_W - PAD_R, y2: baseline_y, class: "stroke-line-strong", stroke_width: "1")
      cumulative_line if @cumulative
    end
  end

  private

  def cumulative_line
    polyline(points: cumulative_points, fill: "none", class: "stroke-ink",
             stroke_width: "2", stroke_linejoin: "round", stroke_linecap: "round")
    circle(cx: center_x(@months.length - 1).round(2),
           cy: cumulative_y(@months.last.cumulative).round(2), r: "3.5", class: "fill-ink")
  end

  def draw_bar(x, value, fill_class)
    h = bar_height(value)
    return if h <= 0

    rect(x: x.round(2), y: (baseline_y - h).round(2), width: bar_w.round(2),
         height: h.round(2), class: fill_class, rx: "1")
  end

  # A short chart is shown smaller, so its labels are set larger to stay readable.
  def label_size = @height < 200 ? "14" : "11"

  def plot_w = VB_W - PAD_L - PAD_R
  def plot_h = @height - PAD_T - PAD_B
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

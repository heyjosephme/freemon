# frozen_string_literal: true

# A small line icon that takes its colour from the surrounding text, for use beside a
# label (it is hidden from screen readers, so never use one alone). Add `class:` for
# the size.
#
# The shapes are from Lucide 0.469.0 (https://lucide.dev), ISC License, copyright
# Lucide Contributors and, for the parts from Feather, Cole Bemis (MIT). They are
# copied in so there is no icon font, package or outside request.
class Components::Icon < Phlex::SVG
  SHAPES = {
    "banknote": [ [ :rect, { width: "20", height: "12", x: "2", y: "6", rx: "2" } ], [ :circle, { cx: "12", cy: "12", r: "2" } ], [ :path, { d: "M6 12h.01M18 12h.01" } ] ],
    "book-open": [ [ :path, { d: "M12 7v14" } ], [ :path, { d: "M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z" } ] ],
    "book-text": [ [ :path, { d: "M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20" } ], [ :path, { d: "M8 11h8" } ], [ :path, { d: "M8 7h6" } ] ],
    "briefcase": [ [ :path, { d: "M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16" } ], [ :rect, { width: "20", height: "14", x: "2", y: "6", rx: "2" } ] ],
    "calculator": [ [ :rect, { width: "16", height: "20", x: "4", y: "2", rx: "2" } ], [ :line, { x1: "8", x2: "16", y1: "6", y2: "6" } ], [ :line, { x1: "16", x2: "16", y1: "14", y2: "18" } ], [ :path, { d: "M16 10h.01" } ], [ :path, { d: "M12 10h.01" } ], [ :path, { d: "M8 10h.01" } ], [ :path, { d: "M12 14h.01" } ], [ :path, { d: "M8 14h.01" } ], [ :path, { d: "M12 18h.01" } ], [ :path, { d: "M8 18h.01" } ] ],
    "chart-column": [ [ :path, { d: "M3 3v16a2 2 0 0 0 2 2h16" } ], [ :path, { d: "M18 17V9" } ], [ :path, { d: "M13 17V5" } ], [ :path, { d: "M8 17v-3" } ] ],
    "circle-minus": [ [ :circle, { cx: "12", cy: "12", r: "10" } ], [ :path, { d: "M8 12h8" } ] ],
    "house": [ [ :path, { d: "M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8" } ], [ :path, { d: "M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" } ] ],
    "landmark": [ [ :line, { x1: "3", x2: "21", y1: "22", y2: "22" } ], [ :line, { x1: "6", x2: "6", y1: "18", y2: "11" } ], [ :line, { x1: "10", x2: "10", y1: "18", y2: "11" } ], [ :line, { x1: "14", x2: "14", y1: "18", y2: "11" } ], [ :line, { x1: "18", x2: "18", y1: "18", y2: "11" } ], [ :polygon, { points: "12 2 20 7 4 7" } ] ],
    "lightbulb": [ [ :path, { d: "M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5" } ], [ :path, { d: "M9 18h6" } ], [ :path, { d: "M10 22h4" } ] ],
    "list-tree": [ [ :path, { d: "M21 12h-8" } ], [ :path, { d: "M21 6H8" } ], [ :path, { d: "M21 18h-8" } ], [ :path, { d: "M3 6v4c0 1.1.9 2 2 2h3" } ], [ :path, { d: "M3 10v6c0 1.1.9 2 2 2h3" } ] ],
    "piggy-bank": [ [ :path, { d: "M19 5c-1.5 0-2.8 1.4-3 2-3.5-1.5-11-.3-11 5 0 1.8 0 3 2 4.5V20h4v-2h3v2h4v-4c1-.5 1.7-1 2-2h2v-4h-2c0-1-.5-1.5-1-2V5z" } ], [ :path, { d: "M2 9v1c0 1.1.9 2 2 2h1" } ], [ :path, { d: "M16 11h.01" } ] ],
    "receipt-japanese-yen": [ [ :path, { d: "M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z" } ], [ :path, { d: "m12 10 3-3" } ], [ :path, { d: "m9 7 3 3v7.5" } ], [ :path, { d: "M9 11h6" } ], [ :path, { d: "M9 15h6" } ] ],
    "repeat": [ [ :path, { d: "m17 2 4 4-4 4" } ], [ :path, { d: "M3 11v-1a4 4 0 0 1 4-4h14" } ], [ :path, { d: "m7 22-4-4 4-4" } ], [ :path, { d: "M21 13v1a4 4 0 0 1-4 4H3" } ] ],
    "scale": [ [ :path, { d: "m16 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z" } ], [ :path, { d: "m2 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z" } ], [ :path, { d: "M7 21h10" } ], [ :path, { d: "M12 3v18" } ], [ :path, { d: "M3 7h2c2 0 5-1 7-2 2 1 5 2 7 2h2" } ] ],
    "settings": [ [ :path, { d: "M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z" } ], [ :circle, { cx: "12", cy: "12", r: "3" } ] ],
    "trending-down": [ [ :polyline, { points: "22 17 13.5 8.5 8.5 13.5 2 7" } ], [ :polyline, { points: "16 17 22 17 22 11" } ] ],
    "trending-up": [ [ :polyline, { points: "22 7 13.5 15.5 8.5 10.5 2 17" } ], [ :polyline, { points: "16 7 22 7 22 13" } ] ]
  }.freeze

  def initialize(name, **attrs)
    @shapes = SHAPES.fetch(name.to_sym)
    @attrs = attrs
  end

  def view_template
    svg(viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "1.75", stroke_linecap: "round",
        stroke_linejoin: "round", aria_hidden: "true", **@attrs) do
      @shapes.each { |tag, shape| public_send(tag, **shape) }
    end
  end
end

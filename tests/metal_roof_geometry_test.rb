# frozen_string_literal: true

require 'testup'

module Examples
  module MetalRoofing
    class GeometryTest < TestUp::TestCase
      def test_parse_roof_length_inches_accepts_inches
        result = MetalRoofing.parse_roof_length_inches('260"')

        assert_equal(260.inch, result)
      end

      def test_parse_roof_length_inches_accepts_plain_integer_as_inches
        result = MetalRoofing.parse_roof_length_inches('288')

        assert_equal(288.inch, result)
      end

      def test_parse_roof_length_inches_accepts_inch_unit
        result = MetalRoofing.parse_roof_length_inches('288"')

        assert_equal(288.inch, result)
      end

      def test_parse_roof_length_inches_accepts_feet_and_inches
        result = MetalRoofing.parse_roof_length_inches("17'-5\"")

        assert_equal((17 * 12 + 5).inch, result)
      end

      def test_roof_slope_uses_a_supported_pitch
        slope = MetalRoofing.roof_slope(6)

        assert_in_delta(0.5, slope.pitch, 1e-9)
        assert_in_delta(Math.atan(0.5), slope.angle, 1e-9)
      end

      def test_roof_slope_rejects_invalid_rise
        assert_raises(ArgumentError) { MetalRoofing.roof_slope(2) }
      end
    end
  end
end

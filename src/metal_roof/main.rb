# frozen_string_literal: true

require 'sketchup.rb'
require 'json'

Sketchup.require 'metal_roof/export_component_json'
Sketchup.require 'metal_roof/flashlighting_ridge_cap'
Sketchup.require 'metal_roof/import_export'
Sketchup.require 'metal_roof/panel_geometry'
Sketchup.require 'metal_roof/roof_construction'
Sketchup.require 'metal_roof/support'

module Examples
  module MetalRoofing

    # Extension registration constants and shared data. Definition of these is
    # allowed in the root file; no business logic belongs here.
    DEFAULT_WIDTH = 288.inch
    LENGTH = 48.inch
    DEFAULT_SLOPE_RISE = 6
    SLOPE_DENOMINATOR = 12
    MIN_SLOPE_RISE = 3
    MAX_SLOPE_RISE = 24
    FRAMING_THICKNESS = 5.5.inch
    SHEATHING_THICKNESS = 0.5.inch
    UNDERLAYMENT_THICKNESS = 0.05.inch
    PANEL_MODULE_WIDTH = 16.inch
    PANEL_THICKNESS = 0.05.inch
    PANEL_TOP_RECESS = 1.inch
    PANEL_COORDINATE_PRECISION = 6
    PANEL_LONGITUDINAL_EDGE_MIN_LENGTH = 4.inch
    PANEL_LONGITUDINAL_DRIFT_TOLERANCE = 0.001.inch
    PANEL_C_FOLD_INNER_EDGE_Y = 1.875.inch
    RIDGE_CAP_PANEL_COVERAGE = 3.inch
    FLASHING_MAX_PIECE_LENGTH = 120.inch
    RIDGE_CAP_REFERENCE_PITCH = 6.0 / SLOPE_DENOMINATOR
    RIDGE_CAP_END_OVERHANG = 1.inch
    RIDGE_CAP_SINGLE_PIECE_MAX_ROOF_LENGTH = 9.5.feet
    RIDGE_CAP_DOUBLE_DOWNFOLD_PROFILE = 'ridge_cap_double_downfold.json'
    RIDGE_CAP_PANEL_SEAM_EXCLUSION_WIDTH = 4.inch
    RIDGE_CAP_PROFILE_TOLERANCE = 1e-6
    SEAM_HEIGHT = 1.5.inch
    FOLD_WIDTH = 0.25.inch
    EAVE_FLASHING_FLANGE_LENGTH = 2.5.inch
    EAVE_FLASHING_DOWNSLOPE_EXTENSION = 1.inch
    EAVE_FLASHING_DOWNLEG_LENGTH = 1.inch
    EAVE_FLASHING_RETURN_LENGTH = 0.25.inch
    EAVE_FLASHING_RETURN_ANGLE = 15.0 * Math::PI / 180
    EAVE_FLASHING_THICKNESS = 0.05.inch
    COMPONENTS = {
      'Metal Roof Assembly' => { tag: 'roof' },
      'Framing' => { tag: 'framing', material: 'Framing' },
      'Sheathing' => { tag: 'sheathing', material: 'Sheathing' },
      'Underlayment' => { tag: 'underlay', material: 'Underlayment' },
      'Eave Drip Flashing' => {
        tag: 'eave-flashing', material: 'Eave Flashing'
      },
      'Ridge Cap' => { tag: 'ridge-cap', material: 'Metal Panels' }
    }.freeze
    RoofSlope = Struct.new(
      :rise, :pitch, :angle, :sin, :cos, :slope_length, :framing_top_offset,
      :flashing_y_offset, :flashing_z_offset, :flashing_local_y_offset,
      :flashing_miter_y, :flashing_local_z_offset,
      keyword_init: true
    )
    LAYER_COLORS = {
      'Framing' => [255, 245, 170],
      'Sheathing' => [105, 175, 105],
      'Underlayment' => [90, 150, 220],
      'Metal Panels' => [160, 165, 170],
      'Eave Flashing' => [160, 165, 170]
    }.freeze
  end
end

unless file_loaded?(__FILE__)
  extension_menu = UI.menu('Extensions')
  extension_menu.add_item('Export Selected Component to JSON') do
    Examples::MetalRoofing.export_component_json
  end
  extension_menu.add_item('Import Component from JSON') do
    Examples::MetalRoofing.import_component_from_json
  end
  extension_menu.add_item('Generate Test Roof Assembly') do
    Examples::MetalRoofing.generate_test_roof_from_prompt
  end
  file_loaded(__FILE__)
end

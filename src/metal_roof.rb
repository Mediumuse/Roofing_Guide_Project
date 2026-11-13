# frozen_string_literal: true

require 'sketchup.rb'
require 'json'

Sketchup.require 'metal_roof/support'
Sketchup.require 'metal_roof/export_component_json'

module Examples
  module MetalRoofing
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new(
        'Metal Roofing Layout & Estimator',
        'metal_roof/main'
      )
      extension.description = 'Creates a sample standing-seam roof assembly.'
      extension.version = '1.0.0'
      extension.creator = 'Roofing Extension Developer'

      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end

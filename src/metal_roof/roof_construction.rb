# frozen_string_literal: true

module Examples
  module MetalRoofing

    # Builds the sample roof assembly by composing the framing, deck, flashing,
    # panels, and ridge-cap layers into a single model group.
    def self.create_test_roof(
      slope_rise = DEFAULT_SLOPE_RISE, roof_width = DEFAULT_WIDTH
    )
      unless roof_width.is_a?(Numeric) && roof_width.finite? && roof_width.positive?
        raise ArgumentError, 'Roof length must be a positive finite number.'
      end

      slope = roof_slope(slope_rise)
      model = Sketchup.active_model
      model.start_operation('Create Test Roof Assembly', true)

      begin
        model.active_entities.grep(Sketchup::Group).each do |group|
          group.erase! if group.name == 'Metal Roof Assembly'
        end
        roof_group = add_component_group(
          model.active_entities, 'Metal Roof Assembly', model: model
        )
        slope_group = add_component_group(
          roof_group.entities, 'Roof Slope A', model: model, tag_name: 'roof'
        )
        entities = slope_group.entities

        add_plumb_cut_framing(entities, slope, roof_width)
        current_z = FRAMING_THICKNESS
        current_z = add_slab(
          entities, 'Sheathing', current_z, SHEATHING_THICKNESS,
          slope.framing_top_offset, slope.slope_length, roof_width
        )
        current_z = add_slab(
          entities, 'Underlayment', current_z, UNDERLAYMENT_THICKNESS,
          slope.framing_top_offset, slope.slope_length, roof_width
        )
        add_eave_flashing(
          entities, current_z, slope.framing_top_offset, slope, roof_width
        )
        add_panels(
          entities, current_z, slope.framing_top_offset, slope,
          slope.framing_top_offset + slope.slope_length, roof_width
        )
        slope_group.transformation = Geom::Transformation.rotation(
          Geom::Point3d.new(0, 0, 0),
          Geom::Vector3d.new(1, 0, 0),
          slope.angle
        )
        opposite_slope = slope_group.copy
        opposite_slope.name = 'Roof Slope B'
        opposite_slope.transform!(
          Geom::Transformation.scaling(
            Geom::Point3d.new(0, LENGTH, 0), 1, -1, 1
          )
        )
        ridge_surface = Geom::Point3d.new(
          0,
          slope.framing_top_offset + slope.slope_length,
          current_z + EAVE_FLASHING_THICKNESS
        ).transform(slope_group.transformation)
        ridge_z = ridge_surface.z + (LENGTH - ridge_surface.y) * slope.pitch +
                  SEAM_HEIGHT / slope.cos
        add_ridge_cap(
          roof_group.entities, model, slope, ridge_z,
          slope.framing_top_offset + slope.slope_length, current_z, roof_width
        )

        model.commit_operation
      rescue StandardError
        model.abort_operation
        raise
      end

      roof_length_feet, roof_length_inches = roof_width.to_f.divmod(12)
      formatted_roof_length = format(
        "%d'-%g\"", roof_length_feet, roof_length_inches
      )
      UI.messagebox(
        format(
          'Test roof assembly created at %s ridge length and %d/12 pitch.',
          formatted_roof_length, slope.rise
        )
      )
    end

    # Converts a roof rise into the derived pitch, angle, and offset values used
    # throughout the geometry math for the framing and flashing layers.
    def self.roof_slope(rise)
      unless rise.is_a?(Integer) && rise.between?(MIN_SLOPE_RISE, MAX_SLOPE_RISE)
        raise ArgumentError,
              "Roof rise must be an integer from #{MIN_SLOPE_RISE} through #{MAX_SLOPE_RISE}."
      end

      pitch = rise.to_f / SLOPE_DENOMINATOR
      angle = Math.atan(pitch)
      pitch_sin = Math.sin(angle)
      pitch_cos = Math.cos(angle)
      flashing_offset = UNDERLAYMENT_THICKNESS - EAVE_FLASHING_THICKNESS
      flashing_y_offset = flashing_offset * pitch_sin
      flashing_z_offset = -flashing_offset * pitch_cos
      flashing_local_y_offset =
        flashing_y_offset * pitch_cos + flashing_z_offset * pitch_sin
      flashing_miter_y =
        -EAVE_FLASHING_THICKNESS * pitch_cos +
        EAVE_FLASHING_THICKNESS * (1 - pitch_sin) / pitch_cos * pitch_sin

      RoofSlope.new(
        rise: rise,
        pitch: pitch,
        angle: angle,
        sin: pitch_sin,
        cos: pitch_cos,
        slope_length: LENGTH * Math.sqrt(1 + pitch**2),
        framing_top_offset: FRAMING_THICKNESS * pitch,
        flashing_y_offset: flashing_y_offset,
        flashing_z_offset: flashing_z_offset,
        flashing_local_y_offset: flashing_local_y_offset,
        flashing_miter_y: flashing_miter_y,
        flashing_local_z_offset: -flashing_y_offset * pitch_sin +
                                 flashing_z_offset * pitch_cos
      )
    end

    # Accepts inches, feet-inch strings, or a plain feet value and normalizes the
    # result into a SketchUp length for the roof-length validation prompt.
    def self.parse_roof_length_inches(value)
      text = value.to_s.strip
      feet_inches = /\A(\d+)\s*'\s*(?:-?\s*(\d+(?:\.\d+)?)\s*"?\s*)?\z/.match(text)
      inches = /\A(\d+(?:\.\d+)?)\s*"?\z/.match(text)
      length = if feet_inches
                 feet_inches[1].to_f * 12 + feet_inches[2].to_f
               elsif inches
                 inches[1].to_f
               end
      return unless length&.finite? && length.positive?

      return if feet_inches && feet_inches[2].to_f >= 12

      length.inch
    end

    # Prompts the user for a roof length and pitch, validates the values, and then
    # builds the reference roof assembly from those inputs.
    def self.generate_test_roof_from_prompt
      input = UI.inputbox(
        ['Roof length along ridge (in, ft-in, or ft):',
         'Roof rise (whole number):'],
        [DEFAULT_WIDTH.to_i.to_s, DEFAULT_SLOPE_RISE],
        'Generate Test Roof Assembly'
      )
      return unless input

      roof_length_inches = parse_roof_length_inches(input[0])
      unless roof_length_inches
        UI.messagebox(
          'Enter a positive roof length in inches (260"), feet and inches ' \
          "(17'-5\"), or feet (52')."
        )
        return
      end

      slope_rise = input[1].to_s
      unless slope_rise.match?(/\A(?:[3-9]|1[0-9]|2[0-4])\z/)
        UI.messagebox(
          "Enter a whole-number roof rise from #{MIN_SLOPE_RISE} through " \
          "#{MAX_SLOPE_RISE}."
        )
        return
      end

      create_test_roof(slope_rise.to_i, roof_length_inches)
    end

    # Accepts inches, feet-inch strings, or a plain feet value and normalizes the
    # result into a SketchUp length for the roof-length validation prompt.
    def self.add_plumb_cut_framing(entities, slope, roof_width)
      group = add_component_group(
        entities, 'Framing', model: Sketchup.active_model
      )

      top_offset = slope.framing_top_offset
      points = [
        Geom::Point3d.new(0, 0, 0),
        Geom::Point3d.new(0, slope.slope_length, 0),
        Geom::Point3d.new(
          0, slope.slope_length + top_offset, FRAMING_THICKNESS
        ),
        Geom::Point3d.new(0, top_offset, FRAMING_THICKNESS)
      ]
      face = group.entities.add_face(points)
      raise 'Could not create the framing profile.' unless face

      face.material = group.material
      face.reverse! if face.normal.x < 0
      face.pushpull(roof_width)
    end

    def self.add_slab(
      entities, name, z, thickness, start_y, slope_length, roof_width
    )
      group = add_component_group(entities, name, model: Sketchup.active_model)
      face = group.entities.add_face(
        Geom::Point3d.new(0, start_y, z),
        Geom::Point3d.new(roof_width, start_y, z),
        Geom::Point3d.new(roof_width, start_y + slope_length, z),
        Geom::Point3d.new(0, start_y + slope_length, z)
      )
      raise "Could not create the #{name.downcase} face." unless face

      face.material = group.material
      face.reverse! if face.normal.z < 0
      face.pushpull(thickness)
      z + thickness
    end

    def self.material_for(model, layer_name)
      material_name = "Metal Roofing - #{layer_name}"
      material = model.materials[material_name] || model.materials.add(material_name)
      material.color = Sketchup::Color.new(*LAYER_COLORS.fetch(layer_name))
      material
    end

    def self.add_component_group(
      entities, name, model:, tag_name: nil, material_name: nil, material: nil
    )
      component = COMPONENTS.fetch(name, {})
      tag_name ||= component.fetch(:tag)
      material_name ||= component[:material]
      group = entities.add_group
      group.name = name
      group.layer = model.layers[tag_name] || model.layers.add(tag_name)
      material ||= material_for(model, material_name) if material_name
      group.material = material if material
      group
    end

    def self.add_eave_flashing(entities, z, start_y, slope, roof_width)
      pitch_sin = slope.sin
      pitch_cos = slope.cos
      local_y_offset = slope.flashing_local_y_offset
      local_z_offset = slope.flashing_local_z_offset
      flashing_start_y = start_y + local_y_offset
      flashing_z = z + local_z_offset
      flange_length = EAVE_FLASHING_FLANGE_LENGTH
      extension = EAVE_FLASHING_DOWNSLOPE_EXTENSION
      downleg_length = EAVE_FLASHING_DOWNLEG_LENGTH
      return_length = EAVE_FLASHING_RETURN_LENGTH
      return_angle = slope.angle + EAVE_FLASHING_RETURN_ANGLE
      thickness = EAVE_FLASHING_THICKNESS
      outside_y = -thickness * pitch_cos
      outside_z = thickness * pitch_sin
      miter_y = slope.flashing_miter_y
      inside_bottom_y = -downleg_length * pitch_sin
      inside_bottom_z = -downleg_length * pitch_cos
      downleg_direction = [-pitch_sin, -pitch_cos]
      downleg_normal = [-pitch_cos, pitch_sin]
      return_direction = [-Math.sin(return_angle), -Math.cos(return_angle)]
      return_normal = [-Math.cos(return_angle), Math.sin(return_angle)]
      downleg_offset = [
        inside_bottom_y + thickness * downleg_normal[0],
        inside_bottom_z + thickness * downleg_normal[1]
      ]
      return_offset = [
        inside_bottom_y + thickness * return_normal[0],
        inside_bottom_z + thickness * return_normal[1]
      ]
      bend_cross = cross_2d(downleg_direction, return_direction)
      offset_delta = [
        return_offset[0] - downleg_offset[0],
        return_offset[1] - downleg_offset[1]
      ]
      miter_run = cross_2d(offset_delta, return_direction) / bend_cross
      bend_miter = [
        downleg_offset[0] + miter_run * downleg_direction[0],
        downleg_offset[1] + miter_run * downleg_direction[1]
      ]
      extension_start_y = miter_y - extension
      extension_join_ratio = thickness / (thickness - bend_miter[1])
      extension_join_y = miter_y +
                         (bend_miter[0] - miter_y) * extension_join_ratio
      return_end = [
        inside_bottom_y + return_length * return_direction[0],
        inside_bottom_z + return_length * return_direction[1]
      ]
      return_outside_end = [
        return_end[0] + thickness * return_normal[0],
        return_end[1] + thickness * return_normal[1]
      ]
      points = [
        Geom::Point3d.new(0, flashing_start_y, flashing_z),
        Geom::Point3d.new(0, flashing_start_y + flange_length, flashing_z),
        Geom::Point3d.new(
          0, flashing_start_y + flange_length, flashing_z + thickness
        ),
        Geom::Point3d.new(
          0, flashing_start_y + extension_start_y, flashing_z + thickness
        ),
        Geom::Point3d.new(0, flashing_start_y + extension_start_y, flashing_z),
        Geom::Point3d.new(0, flashing_start_y + extension_join_y, flashing_z),
        Geom::Point3d.new(
          0, flashing_start_y + bend_miter[0], flashing_z + bend_miter[1]
        ),
        Geom::Point3d.new(
          0,
          flashing_start_y + return_outside_end[0],
          flashing_z + return_outside_end[1]
        ),
        Geom::Point3d.new(
          0, flashing_start_y + return_end[0], flashing_z + return_end[1]
        ),
        Geom::Point3d.new(
          0, flashing_start_y + inside_bottom_y, flashing_z + inside_bottom_z
        )
      ]

      group = add_component_group(
        entities, 'Eave Drip Flashing', model: Sketchup.active_model
      )
      piece_count = (roof_width.to_f / FLASHING_MAX_PIECE_LENGTH).ceil
      piece_length = roof_width.to_f / piece_count
      piece_count.times do |index|
        piece_group = add_component_group(
          group.entities, "Eave Drip Flashing Piece #{index + 1}",
          model: Sketchup.active_model, tag_name: 'eave-flashing',
          material: group.material
        )
        face = piece_group.entities.add_face(points)
        raise 'Could not create the eave drip flashing profile.' unless face

        face.material = group.material
        face.reverse! if face.normal.x < 0
        face.pushpull(piece_length)
        piece_group.transformation = Geom::Transformation.translation(
          Geom::Vector3d.new(index * piece_length, 0, 0)
        )
      end
    end

    # Prompts the user for a roof length and pitch, validates the values, and then
    # builds the reference roof assembly from those inputs.
    def self.add_panels(
      entities, z, start_y, slope, underlayment_end_y, roof_width
    )
      panel_count = (roof_width.to_f / PANEL_MODULE_WIDTH.to_f).ceil
      model = Sketchup.active_model
      panel_material = material_for(model, 'Metal Panels')
      panel_z = z + EAVE_FLASHING_THICKNESS
      panel_start_y = start_y + slope.flashing_local_y_offset +
                      slope.flashing_miter_y -
                      EAVE_FLASHING_DOWNSLOPE_EXTENSION
      folded_panel_start_y = start_y + slope.flashing_local_y_offset +
                             slope.flashing_miter_y - PANEL_THICKNESS
      add_panel_stage(
        entities, model, panel_material, panel_count, panel_start_y, panel_z,
        underlayment_end_y, roof_width, 'Unprepared', 'unprepared',
        'Panel - Unprepared', false
      )
      add_panel_stage(
        entities, model, panel_material, panel_count, panel_start_y, panel_z,
        underlayment_end_y, roof_width, 'Cut', 'cut', 'Panel - Cut', false
      )
      add_panel_stage(
        entities, model, panel_material, panel_count, folded_panel_start_y, panel_z,
        underlayment_end_y, roof_width, 'Folded', 'folded', 'panel-folded', true
      )
    end

    def self.add_panel_stage(
      entities, model, material, panel_count, panel_start_y, panel_z,
      underlayment_end_y, roof_width,
      stage_name, stage_file, tag_name, visible
    )
      stage_data = load_panel_stage(stage_file)
      panel_min_y = stage_data.fetch('faces').flat_map do |face_data|
        face_data.fetch('loops').flatten(1).map { |point| point.fetch(1) }
      end.min.inch
      panel_reference_y = if stage_name == 'Folded'
                            PANEL_C_FOLD_INNER_EDGE_Y
                          else
                            panel_min_y
                          end
      panel_local_end_y = underlayment_end_y -
                          (panel_start_y - panel_reference_y) -
                          PANEL_TOP_RECESS
      full_panel_definition = create_panel_definition(
        model, PANEL_MODULE_WIDTH, material, "Metal Roof Panel - #{stage_name}",
        stage_data, panel_local_end_y
      )
      partial_panel_definition = nil
      stage_layer = add_component_group(
        entities, "#{stage_name} Panels", model: model, tag_name: tag_name,
        material: material
      )
      stage_layer.layer.visible = visible

      panel_count.times do |index|
        x0 = index * PANEL_MODULE_WIDTH
        panel_width = [PANEL_MODULE_WIDTH, roof_width - x0].min
        next if panel_width <= PANEL_THICKNESS * 2

        definition = if panel_width == PANEL_MODULE_WIDTH
                       full_panel_definition
                     else
                       partial_panel_definition ||= create_panel_definition(
                         model, panel_width, material, 'Rip Panel', stage_data,
                         panel_local_end_y
                       )
                     end
        transform = Geom::Transformation.translation(
          Geom::Vector3d.new(x0, panel_start_y - panel_reference_y, panel_z)
        )
        instance = stage_layer.entities.add_instance(definition, transform)
        raise "Could not create #{stage_name.downcase} panel #{index + 1}." unless instance

        instance.name = "#{stage_name} Panel #{index + 1}"
        instance.material = material
      end
    end
  end
end

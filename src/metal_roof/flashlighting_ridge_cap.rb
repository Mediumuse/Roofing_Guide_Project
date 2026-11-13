# frozen_string_literal: true

module Examples
  module MetalRoofing

    # Builds the ridge-cap pieces for the test roof assembly.
    def self.add_ridge_cap(
      entities, model, slope, ridge_z, underlayment_end_y, underlayment_top_z,
      roof_width
    )
      group = add_component_group(entities, 'Ridge Cap', model: model)
      underlayment_end = Geom::Point3d.new(0, underlayment_end_y, underlayment_top_z)
        .transform(
          Geom::Transformation.rotation(
            Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(1, 0, 0), slope.angle
          )
        )
      underlayment_distance_from_ridge =
        (LENGTH - underlayment_end.y) * slope.cos +
        (ridge_z - underlayment_end.z) * slope.sin
      target_roof_reach = underlayment_distance_from_ridge +
                          PANEL_TOP_RECESS + RIDGE_CAP_PANEL_COVERAGE
      cap_length = roof_width + 2 * RIDGE_CAP_END_OVERHANG
      piece_layout = ridge_cap_piece_layout(cap_length)
      piece_definitions = {}
      cap_material = material_for(model, 'Metal Panels')
      piece_layout.each_with_index do |piece, index|
        start_upfold_height = if piece[:type] == :end && index.positive?
                                previous_piece = piece_layout[index - 1]
                                previous_file =
                                  previous_piece[:type] == :end ?
                                    'ridge_cap_end_cut.json' :
                                    'ridge_cap_middle_cut.json'
                                previous_geometry = load_component_geometry(
                                  support_path(previous_file)
                                )
                                abutting_end = previous_piece[:reverse] ? :start : :end
                                complementary_ridge_cap_upfold(
                                  ridge_cap_endpoint_upfold_height(
                                    previous_geometry, abutting_end
                                  )
                                )
                              end
        file_name = case piece[:type]
                    when :middle
                      'ridge_cap_middle_cut.json'
                    when :single
                      RIDGE_CAP_DOUBLE_DOWNFOLD_PROFILE
                    else
                      start_upfold_height ?
                        ridge_cap_end_profile_file(start_upfold_height) :
                        'ridge_cap_end_cut.json'
                    end
        path = support_path(file_name)
        geometry = load_component_geometry(path)
        if start_upfold_height &&
           (ridge_cap_endpoint_upfold_height(geometry, :start) -
            start_upfold_height).abs > RIDGE_CAP_PROFILE_TOLERANCE
          raise "Ridge cap end profile does not match its #{start_upfold_height}-inch joint."
        end
        end_piece = [:end, :single].include?(piece[:type])
        definition_key = [file_name, piece[:length], piece[:reverse], end_piece]
        definition = piece_definitions[definition_key] ||= begin
          component_definition = model.definitions.add(
            "Ridge Cap #{piece[:type].to_s.capitalize} Piece"
          )
          add_ridge_cap_cut_piece_geometry(
            component_definition.entities, geometry, cap_material, model, slope,
            target_roof_reach, piece[:length], piece[:reverse], piece[:type]
          )
          component_definition
        end
        instance = group.entities.add_instance(
          definition,
          Geom::Transformation.translation(Geom::Vector3d.new(piece[:start], 0, 0))
        )
        raise "Could not create #{piece[:name]} component." unless instance

        instance.name = piece[:name]
        instance.layer = model.layers['ridge-cap'] || model.layers.add('ridge-cap')
        instance.material = cap_material
      end
      group.transformation = Geom::Transformation.translation(
        Geom::Vector3d.new(-RIDGE_CAP_END_OVERHANG, LENGTH, ridge_z)
      )
    end

    def self.ridge_cap_piece_layout(cap_length)
      roof_length = cap_length.to_f - 2 * RIDGE_CAP_END_OVERHANG
      if roof_length < RIDGE_CAP_SINGLE_PIECE_MAX_ROOF_LENGTH
        return [
          {
            type: :single,
            name: 'Ridge Cap Single - Both Gables',
            start: 0,
            length: cap_length.to_f,
            reverse: false
          }
        ]
      end

      piece_count = [(cap_length.to_f / FLASHING_MAX_PIECE_LENGTH).ceil, 2].max
      loop do
        boundaries = (0..piece_count).map do |index|
          cap_length.to_f * index / piece_count
        end
        center_index = piece_count / 2
        if piece_count.even? &&
           !ridge_cap_joint_clear?(boundaries[center_index], roof_length)
          piece_count += 1
          next
        end

        retry_with_more_pieces = false
        1.upto((piece_count - 1) / 2) do |index|
          mirror_index = piece_count - index
          next if ridge_cap_joint_clear?(boundaries[index], roof_length) &&
                  ridge_cap_joint_clear?(boundaries[mirror_index], roof_length)

          adjusted_position = ridge_cap_safe_joint_position(
            boundaries, index, mirror_index, cap_length
          )
          unless adjusted_position
            piece_count += 1
            retry_with_more_pieces = true
            break
          end

          boundaries[index] = adjusted_position
          boundaries[mirror_index] = cap_length.to_f - adjusted_position
        end
        next if retry_with_more_pieces

        return (0...piece_count).map do |index|
          end_piece = index.zero? || index == piece_count - 1
          {
            type: end_piece ? :end : :middle,
            name: if index.zero?
                    'Ridge Cap End - Left'
                  elsif index == piece_count - 1
                    'Ridge Cap End - Right'
                  else
                    "Ridge Cap Middle #{index}"
                  end,
            start: boundaries[index],
            length: boundaries[index + 1] - boundaries[index],
            reverse: index < piece_count - 1
          }
        end
      end
    end

    def self.ridge_cap_joint_clear?(cap_position, roof_length)
      panel_seam_count =
        ((roof_length.to_f - RIDGE_CAP_PROFILE_TOLERANCE) /
         PANEL_MODULE_WIDTH.to_f).floor
      half_exclusion_width = RIDGE_CAP_PANEL_SEAM_EXCLUSION_WIDTH / 2.0
      (1..panel_seam_count).all? do |seam_index|
        panel_seam_position =
          RIDGE_CAP_END_OVERHANG + seam_index * PANEL_MODULE_WIDTH
        (cap_position - panel_seam_position).abs >=
          half_exclusion_width - RIDGE_CAP_PROFILE_TOLERANCE
      end
    end

    def self.ridge_cap_safe_joint_position(boundaries, index, mirror_index, cap_length)
      increment = 0.25.inch
      search_steps = (PANEL_MODULE_WIDTH.to_f / increment).ceil
      offsets = (0..search_steps).flat_map do |step|
        step.zero? ? [0] : [step * increment, -step * increment]
      end.sort_by(&:abs)
      current_position = boundaries[index]
      roof_length = cap_length.to_f - 2 * RIDGE_CAP_END_OVERHANG

      offsets.each do |offset|
        candidate = current_position + offset
        mirror_candidate = cap_length.to_f - candidate
        next unless ridge_cap_joint_clear?(candidate, roof_length) &&
                    ridge_cap_joint_clear?(mirror_candidate, roof_length)

        candidate_boundaries = boundaries.dup
        candidate_boundaries[index] = candidate
        candidate_boundaries[mirror_index] = mirror_candidate
        segment_lengths = candidate_boundaries.each_cons(2).map do |start, finish|
          finish - start
        end
        next unless segment_lengths.all? do |length|
          length.positive? &&
            length <= FLASHING_MAX_PIECE_LENGTH + RIDGE_CAP_PROFILE_TOLERANCE
        end

        return candidate
      end
      nil
    end

    # Reads the upfold height at one end of a ridge-cap profile measured along
    # the reference pitch.
    def self.ridge_cap_endpoint_upfold_height(geometry, endpoint)
      points = geometry.fetch('faces').flat_map do |face_data|
        face_data.fetch('loops').fetch(0)
      end
      x_values = points.map { |point| Float(point.fetch(0)) }
      x_stations = x_values.map { |value| value.round(PANEL_COORDINATE_PRECISION) }
                           .uniq.sort
      unless x_stations.length >= 4
        raise 'Ridge cap profile has no measurable end sections.'
      end

      end_points = if endpoint == :start
                     points.select do |point|
                       point.fetch(0) <= x_stations[1] + RIDGE_CAP_PROFILE_TOLERANCE
                     end
                   else
                     points.select do |point|
                       point.fetch(0) >= x_stations[-2] - RIDGE_CAP_PROFILE_TOLERANCE
                     end
                   end
      source_angle = Math.atan(RIDGE_CAP_REFERENCE_PITCH)
      source_sin = Math.sin(source_angle)
      source_cos = Math.cos(source_angle)
      end_points.map do |point|
        y = Float(point.fetch(1))
        z = Float(point.fetch(2))
        y.abs * source_sin + z * source_cos
      end.max - PANEL_THICKNESS
    rescue KeyError, TypeError, ArgumentError => error
      raise "Invalid ridge cap end profile: #{error.message}"
    end

    def self.complementary_ridge_cap_upfold(height)
      known_heights = [0.5.inch, 1.inch]
      match = known_heights.find do |candidate|
        (height - candidate).abs <= RIDGE_CAP_PROFILE_TOLERANCE
      end
      raise "Unsupported ridge-cap upfold height: #{height}." unless match

      (known_heights - [match]).first
    end

    def self.ridge_cap_end_profile_file(upfold_height)
      known_heights = {
        0.5.inch => 'Ridge_Cap_End_-_Right_with_0.5_square_foldup.json',
        1.inch => 'ridge_cap_end_cut.json'
      }
      match = known_heights.keys.find do |candidate|
        (upfold_height - candidate).abs <= RIDGE_CAP_PROFILE_TOLERANCE
      end
      raise "Unsupported ridge-cap end upfold height: #{upfold_height}." unless match

      known_heights.fetch(match)
    end

    # Converts a JSON profile into a reusable component definition for a single
    # ridge-cap cut piece.
    def self.add_ridge_cap_cut_piece_geometry(
      entities, geometry, material, model, slope, target_roof_reach,
      piece_length, reverse, piece_type
    )
      source_faces = geometry.fetch('faces')
      coordinates = source_faces.flat_map do |face_data|
        loops = face_data.fetch('loops')
        raise 'Ridge cap faces cannot have inner loops.' unless loops.length == 1

        loops.first
      end
      points = coordinates.map do |point|
        unless point.is_a?(Array) && point.length == 3
          raise 'Ridge cap JSON contains an invalid point.'
        end

        point.map do |coordinate|
          value = Float(coordinate)
          raise 'Ridge cap JSON contains a non-finite point.' unless value.finite?

          value
        end
      end
      x_values = points.map(&:first)
      x_min = x_values.min
      x_max = x_values.max
      x_span = x_max - x_min
      x_stations = x_values.map { |value| value.round(PANEL_COORDINATE_PRECISION) }
                           .uniq.sort
      unless x_stations.length >= 4
        raise 'Ridge cap cut profile needs distinct start, body, and end sections.'
      end

      start_feature_end_index = piece_type == :single ? 2 : 1
      end_feature_start_index = piece_type == :single ? -3 : -2
      start_feature_end = x_stations.fetch(start_feature_end_index)
      end_feature_start = x_stations.fetch(end_feature_start_index)
      start_feature_length = start_feature_end - x_min
      end_feature_length = x_max - end_feature_start
      source_body_length = x_span - start_feature_length - end_feature_length
      target_body_length = piece_length - start_feature_length - end_feature_length
      unless source_body_length.positive? && target_body_length.positive?
        raise 'Ridge cap piece is too short for its end details.'
      end

      body_scale = target_body_length / source_body_length
      reference_angle = Math.atan(RIDGE_CAP_REFERENCE_PITCH)
      source_sin = Math.sin(reference_angle)
      source_cos = Math.cos(reference_angle)
      center_y = 0.0
      center_z = 0.0
      source_roof_reach = points.map do |point|
        (point[1] - center_y).abs * source_cos -
          (point[2] - center_z) * source_sin
      end.max
      unless source_roof_reach&.positive?
        raise 'Ridge cap cut profile has no downslope reach.'
      end
      unless points.any? do |point|
        point[1].abs <= RIDGE_CAP_PROFILE_TOLERANCE &&
          point[2].abs <= RIDGE_CAP_PROFILE_TOLERANCE
      end
        raise 'Ridge cap cut profile must place its underside reference at the origin.'
      end
      roof_reach_scale = target_roof_reach.to_f / source_roof_reach
      material_data = geometry['materials']
      created_faces = 0

      source_faces.each_with_index do |face_data, face_index|
        source_points = face_data.fetch('loops').first.map do |x, y, z|
          mapped_x = ridge_cap_cut_piece_x(
            x, x_min, start_feature_end, end_feature_start, start_feature_length,
            target_body_length, body_scale, piece_length, reverse
          )
          Geom::Point3d.new(mapped_x, y, z)
        end
        polygons = face_polygons(simplify_polygon(source_points))
        raise "Could not interpret Ridge Cap face #{face_index + 1}." unless polygons

        polygons.each do |polygon|
          ridge_cap_polygon_sides(polygon, center_y).each do |side, side_polygon|
            profile_points = if side.zero?
                               nil
                             else
                               side_polygon.map do |point|
                                 ridge_cap_profile_point(
                                   point, 0, 1, center_y, center_z, side,
                                   source_sin, source_cos, roof_reach_scale
                                 )
                               end
            end
            mapped_points = if side.zero?
                              side_polygon.map do |point|
                                Geom::Point3d.new(
                                  panel_coordinate(point.x), 0,
                                  panel_coordinate(point.z - center_z)
                                )
                              end
                            else
                              profile_points.map do |profile_point|
                                ridge_cap_project_point(
                                  profile_point, side, slope
                                )
                              end
                            end
            mapped_polygons = face_polygons(
              simplify_polygon(mapped_points)
            )
            next unless mapped_polygons

            mapped_faces = []
            mapped_polygons.each do |face_points|
              face = entities.add_face(face_points)
              raise "Could not create Ridge Cap face #{face_index + 1}." unless face

              face.reverse! if reverse
              face.material = imported_face_material(
                model, face_data['front_material'], material, material_data
              )
              face.back_material = imported_face_material(
                model, face_data['back_material'], material, material_data
              )
              mapped_faces << face
              created_faces += 1
            end
            if [:end, :single].include?(piece_type) && mapped_faces.length > 1
              hide_ridge_cap_tessellation_edges(mapped_faces)
            end
          end
        end
      end
      raise 'Ridge cap cut profile produced no faces.' if created_faces.zero?
    rescue KeyError, TypeError, ArgumentError => error
      raise "Invalid ridge cap cut geometry: #{error.message}"
    end

    def self.hide_ridge_cap_tessellation_edges(faces)
      faces.compact.uniq.each do |face|
        face.edges.each do |edge|
          shared_face_count = edge.faces.count do |adjacent_face|
            faces.include?(adjacent_face)
          end
          edge.hidden = true if shared_face_count > 1
        end
      end
    end

    def self.ridge_cap_cut_piece_x(
      x, x_min, start_body_x, end_body_x, start_feature_length,
      target_body_length, body_scale, piece_length, reverse
    )
      mapped_x = if x <= start_body_x + RIDGE_CAP_PROFILE_TOLERANCE
                   x - x_min
                 elsif x >= end_body_x - RIDGE_CAP_PROFILE_TOLERANCE
                   target_body_length + start_feature_length +
                     x - end_body_x
                 else
                   start_feature_length + (x - start_body_x) * body_scale
                 end
      reverse ? piece_length - mapped_x : mapped_x
    end

    def self.ridge_cap_polygon_sides(points, center_y)
      y_values = points.map(&:y)
      minimum_y = y_values.min
      maximum_y = y_values.max
      tolerance = RIDGE_CAP_PROFILE_TOLERANCE
      return [[0, points]] if maximum_y - minimum_y <= tolerance
      return [[-1, points]] if maximum_y <= center_y + tolerance
      return [[1, points]] if minimum_y >= center_y - tolerance

      [-1, 1].filter_map do |side|
        clipped = clip_ridge_cap_at_center(points, center_y, side)
        [side, clipped] if clipped.length >= 3
      end
    end

    def self.clip_ridge_cap_at_center(points, center_y, side)
      clipped = []
      previous = points.last
      previous_inside = side.negative? ? previous.y <= center_y : previous.y >= center_y
      points.each do |current|
        current_inside = side.negative? ? current.y <= center_y : current.y >= center_y
        if current_inside
          unless previous_inside
            clipped << ridge_cap_center_intersection(
              previous, current, center_y
            )
          end
          clipped << current
        elsif previous_inside
          clipped << ridge_cap_center_intersection(
            previous, current, center_y
          )
        end
        previous = current
        previous_inside = current_inside
      end
      clipped
    end

    def self.ridge_cap_center_intersection(point_a, point_b, center_y)
      ratio = (center_y - point_a.y) / (point_b.y - point_a.y)
      Geom::Point3d.new(
        point_a.x + (point_b.x - point_a.x) * ratio,
        center_y,
        point_a.z + (point_b.z - point_a.z) * ratio
      )
    end

    def self.ridge_cap_profile_point(
      point, x_min, x_scale, center_y, center_z, side, source_sin, source_cos,
      roof_reach_scale
    )
      delta_y = point.y - center_y
      delta_z = point.z - center_z
      [
        (point.x - x_min) * x_scale,
        (delta_y * side * source_cos - delta_z * source_sin) *
          roof_reach_scale,
        delta_y * side * source_sin + delta_z * source_cos,
        delta_z,
        delta_y.abs <= RIDGE_CAP_PROFILE_TOLERANCE
      ]
    end

    def self.ridge_cap_project_point(profile_point, side, slope)
      x, distance, normal_offset, centerline_z, centerline = profile_point
      if centerline
        return Geom::Point3d.new(
          panel_coordinate(x), 0, panel_coordinate(centerline_z)
        )
      end

      Geom::Point3d.new(
        panel_coordinate(x),
        panel_coordinate(
          side * (distance * slope.cos + normal_offset * slope.sin)
        ),
        panel_coordinate(
          -distance * slope.sin + normal_offset * slope.cos
        )
      )
    end

  end
end

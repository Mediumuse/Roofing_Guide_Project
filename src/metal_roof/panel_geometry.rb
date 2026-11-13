# frozen_string_literal: true

module Examples
  module MetalRoofing

    # Validates the folded-stage panel extrusion by checking that every
    # longitudinal edge stays straight and parallel to the roof run.
    def self.validate_panel_extrusion(stage_data, path)
      worst_edge = nil
      stage_data.fetch('faces').each_with_index do |face_data, face_index|
        face_data.fetch('loops').each do |loop|
          loop.each_with_index do |point_a, point_index|
            point_b = loop[(point_index + 1) % loop.length]
            run = (point_b.fetch(1) - point_a.fetch(1)).abs.inch
            next if run < PANEL_LONGITUDINAL_EDGE_MIN_LENGTH

            drift = Math.sqrt(
              (point_b.fetch(0) - point_a.fetch(0))**2 +
              (point_b.fetch(2) - point_a.fetch(2))**2
            ).inch
            next if drift <= PANEL_LONGITUDINAL_DRIFT_TOLERANCE
            next if worst_edge && drift <= worst_edge.fetch(:drift)

            worst_edge = {
              face: face_index + 1,
              edge: point_index + 1,
              run: run,
              drift: drift
            }
          end
        end
      end
      return unless worst_edge

      raise format(
        'Folded panel extrusion check failed in %s: face %d edge %d drifts %.4f in ' \
        'across %.3f in; longitudinal edges must remain straight and parallel to the roof run.',
        path, worst_edge.fetch(:face), worst_edge.fetch(:edge),
        worst_edge.fetch(:drift), worst_edge.fetch(:run)
      )
    end

    # Builds a reusable panel component definition for a given stage.
    def self.create_panel_definition(
      model, width, material, name, stage_data, panel_end_y
    )
      panel_definition = model.definitions.add(name)
      rip_edge_x = (PANEL_MODULE_WIDTH - FOLD_WIDTH - PANEL_THICKNESS).to_f
      stage_max_y = stage_data.fetch('faces').flat_map do |face_data|
        face_data.fetch('loops').flatten(1).map { |point| point.fetch(1) }
      end.max.to_f
      panel_end_y_inches = panel_end_y.to_f / 1.inch
      extend_panel_to_end = stage_max_y < panel_end_y_inches - 1e-6
      stage_data.fetch('faces').each_with_index do |face_data, index|
        loops = face_data.fetch('loops')
        raise "Unsupported inner loop in #{name} face #{index + 1}." unless loops.length == 1

        points = loops.first.map do |x, y, z|
          if x >= rip_edge_x
            x += width.to_f - PANEL_MODULE_WIDTH.to_f
          end
          if extend_panel_to_end && (y.to_f - stage_max_y).abs <= 1e-6
            y = panel_end_y_inches
          end
          Geom::Point3d.new(
            panel_coordinate(x), panel_coordinate(y), panel_coordinate(z)
          )
        end
        source_polygons = face_polygons(simplify_polygon(points))
        source_polygons.each do |source_points|
          clipped_points = clip_panel_polygon_to_roof_run(
            source_points, panel_end_y
          )
          next if clipped_points.length < 3

          face_pieces = face_polygons(
            simplify_polygon(clipped_points)
          )
          face_pieces.each do |face_points|
            face = panel_definition.entities.add_face(face_points)
            unless face
              raise "Could not create #{name.downcase} face #{index + 1}."
            end

            face.material = material
            face.back_material = material
          end
        end
      end
      merge_coplanar_panel_edges(panel_definition)

      panel_definition
    end

    def self.merge_coplanar_panel_edges(panel_definition)
      panel_definition.entities.grep(Sketchup::Edge).each do |edge|
        next unless edge.valid? && edge.faces.length == 2

        normal_a, normal_b = edge.faces.map(&:normal)
        next unless normal_a.dot(normal_b).abs >= 1.0 - 1e-8

        edge.erase!
      end
    end

    def self.panel_coordinate(value)
      value.to_f.round(PANEL_COORDINATE_PRECISION).inch
    end

    def self.clip_panel_polygon_to_roof_run(points, slope_length)
      clipped = []
      previous = points.last
      previous_inside = previous.y <= slope_length
      points.each do |current|
        current_inside = current.y <= slope_length
        if current_inside
          clipped << panel_run_intersection(
            previous, current, slope_length
          ) unless previous_inside
          clipped << current
        elsif previous_inside
          clipped << panel_run_intersection(previous, current, slope_length)
        end
        previous = current
        previous_inside = current_inside
      end
      clipped.each_with_object([]) do |point, unique_points|
        unique_points << point if unique_points.empty? ||
                                    unique_points.last.distance(point) > 1e-8
      end.tap do |unique_points|
        unique_points.pop if unique_points.length > 1 &&
                             unique_points.first.distance(unique_points.last) <= 1e-8
      end
    end

    def self.panel_run_intersection(point_a, point_b, slope_length)
      ratio = (slope_length - point_a.y) / (point_b.y - point_a.y)
      Geom::Point3d.new(
        point_a.x + (point_b.x - point_a.x) * ratio,
        slope_length,
        point_a.z + (point_b.z - point_a.z) * ratio
      )
    end

    # Loads a prebuilt panel profile from JSON and validates the extrusion for the
    # folded-stage panels before they are instanced into the model.
    def self.load_panel_stage(stage_name)
      path = support_path("panel_#{stage_name}.json")
      stage_data = load_component_geometry(path)
      validate_panel_extrusion(stage_data, path) if stage_name == 'folded'

      stage_data
    end

    def self.load_component_geometry(path)
      geometry = JSON.parse(File.read(path))
      unless geometry.is_a?(Hash) && geometry['format_version'] == 1
        raise "Unsupported component geometry file version: #{path}"
      end
      raise "Component geometry must use inches: #{path}" unless geometry['units'] == 'inches'
      raise "Component geometry file has no faces: #{path}" unless geometry['faces'].is_a?(Array) &&
                                                                    !geometry['faces'].empty?

      geometry
    end

    # Removes collinear points from a polygon, reducing vertex count without
    # changing its shape.
    def self.simplify_polygon(points)
      simplified = points.dup
      loop do
        break if simplified.length <= 3

        removable_index = simplified.each_index.find do |index|
          previous = simplified[(index - 1) % simplified.length]
          current = simplified[index]
          following = simplified[(index + 1) % simplified.length]
          first = [current.x - previous.x, current.y - previous.y,
                   current.z - previous.z]
          second = [following.x - current.x, following.y - current.y,
                    following.z - current.z]
          dot = first.zip(second).sum { |a, b| a * b }
          next false if dot.negative?

          cross = [
            first[1] * second[2] - first[2] * second[1],
            first[2] * second[0] - first[0] * second[2],
            first[0] * second[1] - first[1] * second[0]
          ]
          cross_length = Math.sqrt(cross.sum { |component| component * component })
          first_length = Math.sqrt(first.sum { |component| component * component })
          second_length = Math.sqrt(second.sum { |component| component * component })
          cross_length <= 1e-6 * (first_length + second_length)
        end
        break unless removable_index

        simplified.delete_at(removable_index)
      end
      simplified
    end

    def self.face_polygons(points)
      origin = points.first
      normal = nil
      largest_normal_length = 0
      points[1...-1].each_with_index do |point_b, index|
        (index + 2...points.length).each do |point_index|
          point_c = points[point_index]
          vector_a = [
            point_b.x - origin.x, point_b.y - origin.y, point_b.z - origin.z
          ]
          vector_b = [
            point_c.x - origin.x, point_c.y - origin.y, point_c.z - origin.z
          ]
          candidate = [
            vector_a[1] * vector_b[2] - vector_a[2] * vector_b[1],
            vector_a[2] * vector_b[0] - vector_a[0] * vector_b[2],
            vector_a[0] * vector_b[1] - vector_a[1] * vector_b[0]
          ]
          length = Math.sqrt(candidate.sum { |component| component * component })
          next if length <= largest_normal_length

          largest_normal_length = length
          normal = candidate.map { |component| component / length }
        end
      end
      return unless normal

      max_deviation = points.map do |point|
        (point.x - origin.x) * normal[0] +
          (point.y - origin.y) * normal[1] +
          (point.z - origin.z) * normal[2]
      end.map(&:abs).max
      return [points] if max_deviation <= 1e-7

      if max_deviation <= 1e-5
        flattened_points = points.map do |point|
          deviation = (point.x - origin.x) * normal[0] +
                      (point.y - origin.y) * normal[1] +
                      (point.z - origin.z) * normal[2]
          Geom::Point3d.new(
            point.x - deviation * normal[0],
            point.y - deviation * normal[1],
            point.z - deviation * normal[2]
          )
        end
        return [flattened_points]
      end

      polygon_normal = [
        points.each_with_index.sum do |point, index|
          next_point = points[(index + 1) % points.length]
          (point.y - next_point.y) * (point.z + next_point.z)
        end,
        points.each_with_index.sum do |point, index|
          next_point = points[(index + 1) % points.length]
          (point.z - next_point.z) * (point.x + next_point.x)
        end,
        points.each_with_index.sum do |point, index|
          next_point = points[(index + 1) % points.length]
          (point.x - next_point.x) * (point.y + next_point.y)
        end
      ]
      drop_axis = polygon_normal.each_with_index
                                .max_by { |component, _index| component.abs }
                                .last
      projected = points.map do |point|
        case drop_axis
        when 0 then [point.y, point.z]
        when 1 then [point.x, point.z]
        else [point.x, point.y]
        end
      end
      area = projected.each_with_index.sum do |point, index|
        next_point = projected[(index + 1) % projected.length]
        point[0] * next_point[1] - next_point[0] * point[1]
      end
      return triangulate_nonplanar_polygon(points, projected, area) unless points.length == 4

      diagonal_02 = [
        cross_2d(subtract_2d(projected[1], projected[0]),
                 subtract_2d(projected[2], projected[0])),
        cross_2d(subtract_2d(projected[2], projected[0]),
                 subtract_2d(projected[3], projected[0]))
      ]
      diagonal_13 = [
        cross_2d(subtract_2d(projected[1], projected[0]),
                 subtract_2d(projected[3], projected[0])),
        cross_2d(subtract_2d(projected[2], projected[1]),
                 subtract_2d(projected[3], projected[1]))
      ]
      valid_02 = diagonal_02.all? { |cross| cross * area > 1e-9 }
      valid_13 = diagonal_13.all? { |cross| cross * area > 1e-9 }
      diagonal_length_02 = origin.distance(points[2])
      diagonal_length_13 = points[1].distance(points[3])

      if valid_02 && (!valid_13 || diagonal_length_02 <= diagonal_length_13)
        [[points[0], points[1], points[2]], [points[0], points[2], points[3]]]
      elsif valid_13
        [[points[0], points[1], points[3]], [points[1], points[2], points[3]]]
      else
        raise 'Could not triangulate nonplanar face quadrilateral.'
      end
    end

    def self.triangulate_nonplanar_polygon(points, projected, area)
      raise 'Cannot triangulate a degenerate nonplanar face.' if area.abs <= 1e-9

      indices = (0...points.length).to_a
      triangles = []
      while indices.length > 3
        ear_position = indices.each_index.find do |position|
          previous_index = indices[(position - 1) % indices.length]
          current_index = indices[position]
          following_index = indices[(position + 1) % indices.length]
          previous = projected[previous_index]
          current = projected[current_index]
          following = projected[following_index]
          cross = cross_2d(
            subtract_2d(current, previous),
            subtract_2d(following, current)
          )
          next false unless cross * area > 1e-9

          indices.none? do |index|
            next false if [previous_index, current_index, following_index].include?(index)

            point_in_projected_triangle?(
              projected[index], previous, current, following, area
            )
          end
        end
        raise 'Could not triangulate nonplanar face.' unless ear_position

        previous_index = indices[(ear_position - 1) % indices.length]
        current_index = indices[ear_position]
        following_index = indices[(ear_position + 1) % indices.length]
        triangles << [
          points[previous_index], points[current_index], points[following_index]
        ]
        indices.delete_at(ear_position)
      end
      triangles << indices.map { |index| points[index] }
      triangles
    end

    def self.point_in_projected_triangle?(point, point_a, point_b, point_c, area)
      [
        cross_2d(subtract_2d(point_b, point_a), subtract_2d(point, point_a)),
        cross_2d(subtract_2d(point_c, point_b), subtract_2d(point, point_b)),
        cross_2d(subtract_2d(point_a, point_c), subtract_2d(point, point_c))
      ].all? { |cross| cross * area >= -1e-9 }
    end

    def self.subtract_2d(point_a, point_b)
      [point_a[0] - point_b[0], point_a[1] - point_b[1]]
    end

    # 2D cross product of two vectors.
    def self.cross_2d(vector_a, vector_b)
      vector_a[0] * vector_b[1] - vector_a[1] * vector_b[0]
    end
  end
end

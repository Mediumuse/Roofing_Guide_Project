# frozen_string_literal: true

module Examples
  module MetalRoofing

    # Imports the geometry from a component JSON file into the model as a static
    # component instance at the user-supplied origin.
    def self.import_component_from_json
      project_root = support_path
      path = UI.openpanel(
        'Select component geometry JSON', project_root, 'JSON Files|*.json||'
      )
      return unless path

      geometry = load_component_geometry(path)
      component_name = geometry['component_name'] || geometry['definition_name']
      raise "Component name is missing from #{path}." if component_name.to_s.empty?

      default_tag = component_name.downcase.gsub(/[^a-z0-9]+/, '-')
        .gsub(/\A-+|-+\z/, '')
      input = UI.inputbox(
        ['Component name:', 'Tag:', 'Material:', 'Origin X (inches):',
         'Origin Y (inches):', 'Origin Z (inches):'],
        [component_name, default_tag, "Metal Roofing - #{component_name}", 0, 0, 0],
        'Import Component Geometry'
      )
      return unless input

      name, tag_name, material_name, x, y, z = input
      raise 'Component name, tag, and material are required.' if
        [name, tag_name, material_name].any? { |value| value.to_s.strip.empty? }

      origin = [x, y, z].map do |coordinate|
        value = Float(coordinate)
        raise 'Component origin coordinates must be finite numbers.' unless value.finite?

        value.inch
      end
      model = Sketchup.active_model
      model.start_operation("Import #{name}", true)

      begin
        material = model.materials[material_name]
        unless material
          material = model.materials.add(material_name)
          material.color = Sketchup::Color.new(*LAYER_COLORS.fetch('Metal Panels'))
        end
        definition = model.definitions.add(name)
        add_component_geometry(
          definition.entities, geometry, material, model, name
        )
        instance = model.active_entities.add_instance(
          definition,
          Geom::Transformation.translation(Geom::Vector3d.new(*origin))
        )
        raise "Could not create component instance #{name}." unless instance

        instance.name = name
        instance.layer = model.layers[tag_name] || model.layers.add(tag_name)
        instance.material = material
        model.commit_operation
      rescue StandardError
        model.abort_operation
        raise
      end

      UI.messagebox("Imported #{name} from:\n#{path}")
    rescue StandardError => error
      UI.messagebox("Component import failed: #{error.message}")
      raise
    end

    def self.add_component_geometry(entities, geometry, material, model, name)
      geometry.fetch('faces').each_with_index do |face_data, face_index|
        loops = face_data.fetch('loops')
        unless loops.is_a?(Array) && loops.length == 1
          raise "Unsupported inner loop in #{name} face #{face_index + 1}."
        end
        unless loops.first.is_a?(Array) && loops.first.length >= 3
          raise "Invalid boundary in #{name} face #{face_index + 1}."
        end

        points = loops.first.map do |coordinates|
          unless coordinates.is_a?(Array) && coordinates.length == 3
            raise "Invalid point in #{name} face #{face_index + 1}."
          end

          values = coordinates.map do |coordinate|
            value = Float(coordinate)
            raise "Non-finite point in #{name} face #{face_index + 1}." unless value.finite?

            value.inch
          end
          Geom::Point3d.new(*values)
        end
        polygons = face_polygons(simplify_polygon(points))
        raise "Could not interpret #{name} face #{face_index + 1}." unless polygons

        polygons.each do |polygon|
          face = entities.add_face(polygon)
          raise "Could not create #{name} face #{face_index + 1}." unless face

          face.material = imported_face_material(
            model, face_data['front_material'], material, geometry['materials']
          )
          face.back_material = imported_face_material(
            model, face_data['back_material'], material, geometry['materials']
          )
        end
      end
    rescue KeyError, TypeError, ArgumentError => error
      raise "Invalid component geometry for #{name}: #{error.message}"
    end

    def self.imported_face_material(model, material_name, fallback, material_data)
      return fallback if material_name.to_s.empty?

      existing = model.materials[material_name]
      return existing if existing

      material = model.materials.add(material_name)
      properties = material_data.is_a?(Hash) ? material_data[material_name] : nil
      color = properties.is_a?(Hash) ? properties['color'] : nil
      if color.is_a?(Array) && color.length == 3
        material.color = Sketchup::Color.new(*color)
      else
        material.color = fallback.color
      end

      alpha = properties['alpha'] if properties.is_a?(Hash)
      material.alpha = alpha if alpha.is_a?(Numeric) && alpha.between?(0, 1)
      material
    end
  end
end

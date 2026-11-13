# frozen_string_literal: true

require 'json'

module Examples
  module MetalRoofing
    def self.export_component_json
      model = Sketchup.active_model
      instance = model.selection.find do |entity|
        entity.is_a?(Sketchup::Group) ||
          entity.is_a?(Sketchup::ComponentInstance)
      end

      unless instance
        UI.messagebox('Select one component or group first.')
        return
      end

      default_name = instance.name.empty? ? instance.definition.name : instance.name
      input = UI.inputbox(
        ['Component name:'], [default_name], 'Export Component Geometry'
      )
      return unless input

      component_name = input[0].strip
      if component_name.empty?
        UI.messagebox('Enter a component name.')
        return
      end

      faces = []
      materials = {}
      walk = nil
      walk = lambda do |entities, transform|
        entities.each do |entity|
          if entity.is_a?(Sketchup::Face)
            loops = entity.loops.map do |face_loop|
              face_loop.vertices.map do |vertex|
                point = vertex.position.transform(transform)
                [
                  point.x.to_f / 1.inch,
                  point.y.to_f / 1.inch,
                  point.z.to_f / 1.inch
                ]
              end
            end

            [entity.material, entity.back_material].compact.each do |material|
              color = material.color
              materials[material.name] = {
                color: [color.red, color.green, color.blue],
                alpha: material.alpha
              }
            end

            faces << {
              loops: loops,
              front_material: entity.material&.name,
              back_material: entity.back_material&.name
            }
          elsif entity.is_a?(Sketchup::Group) ||
                entity.is_a?(Sketchup::ComponentInstance)
            walk.call(
              entity.definition.entities,
              transform * entity.transformation
            )
          end
        end
      end

      walk.call(instance.definition.entities, Geom::Transformation.new)
      if faces.empty?
        UI.messagebox('The selected component or group contains no faces.')
        return
      end

      safe_name = component_name.gsub(/[^\w.-]+/, '_')
      path = UI.savepanel(
        'Save component geometry',
        nil,
        "#{safe_name}.json"
      )
      return unless path

      data = {
        format_version: 1,
        component_name: component_name,
        stage: component_name,
        units: 'inches',
        definition_name: instance.definition.name,
        instance_transform: instance.transformation.to_a,
        materials: materials,
        faces: faces
      }

      File.write(path, JSON.pretty_generate(data))
      UI.messagebox("Exported #{faces.length} faces:\n#{path}")
    end
  end
end

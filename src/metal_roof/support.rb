# frozen_string_literal: true

module Examples
  module MetalRoofing
    module_function

    def support_path(*path_parts)
      roots = [
        File.expand_path(File.join(File.dirname(__FILE__), '..', '..')),
        File.expand_path(File.join(File.dirname(__FILE__), '..')),
        File.expand_path(File.dirname(__FILE__))
      ]

      roots.each do |root|
        candidate = File.expand_path(File.join(root, *path_parts))
        return candidate if File.exist?(candidate)
      end

      fallback = File.expand_path(File.join(roots.first, *path_parts))
      raise "Unable to resolve the Metal Roofing extension support path: #{fallback}"
    end
  end
end

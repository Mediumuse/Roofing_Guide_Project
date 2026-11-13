#!/usr/bin/env ruby
# norm-lf.rb -- rewrite every tracked file that contains CRLF, to plain LF.
# Byte-level; no Ruby string-encoding assumptions. Safe to re-run.
$LOAD_PATH << File.expand_path("tools", __dir__)
require "open3"

ROOT = File.expand_path("..", __dir__)

def crlf_pairs?(path)
  prev_cr = false
  File.foreach(path, mode: "rb") do |line|
    line.bytes.each do |b|
      next unless b == 13 # \r
      # the next byte decides; we need to look ahead, so use a small window
      # Instead: check this byte and the following byte in the stream via pos
      # Simpler robust approach: read whole file as bytes once (files are small).
    end
  end
  nil
end

# Byte-level CRLF detection + rewrite.
def normalize(file)
  data = File.binread(file)
  return nil unless data.include?(13.chr + 10.chr) # \r\n present

  # Rebuild: any \r\n becomes \n.
  out = String.new(data.force_encoding(Encoding::BINARY))
  out.gsub!(/\r\n/, "\n")

  File.binwrite(file, out)
  [file, data.bytesize, out.bytesize]
end

files = `git ls-files`.split("\n").map(&:strip).reject(&:empty?)
normalized = files.filter_map do |rel|
  path = File.join(ROOT, rel)
  next unless File.exist?(path)
  next unless File.binread(path).include?(13.chr + 10.chr)
  a = File.binread(path).bytesize
  File.binwrite(path, File.binread(path).gsub(/\r\n/, "\n"))
  b = File.binread(path).bytesize
  next unless b < a
  rel
end

puts "normalized=#{normalized.length}"
normalized.each { |f| puts "  - #{f}" }

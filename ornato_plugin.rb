# ornato_plugin.rb — Loader principal do plugin Ornato para SketchUp
# Este arquivo deve ser colocado na pasta Plugins do SketchUp

require 'sketchup.rb'
require 'extensions.rb'

module Ornato
  PLUGIN_NAME    = 'Ornato Marcenaria'.freeze
  PLUGIN_VERSION = '0.1.0'.freeze
  PLUGIN_DIR     = File.join(File.dirname(__FILE__), 'ornato_plugin').freeze

  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new(PLUGIN_NAME, File.join(PLUGIN_DIR, 'main'))
    ext.description = 'Plugin de marcenaria parametrica integrado ao Ornato ERP'
    ext.version     = PLUGIN_VERSION
    ext.creator     = 'Ornato'
    ext.copyright   = "2026 Ornato"

    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end

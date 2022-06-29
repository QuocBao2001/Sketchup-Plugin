# Dùng để Sketchup nạp src/main
require 'sketchup'
require 'extensions'

module TheTich
  module TheTichKimLoai
    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('The tich kim loai', 'src/main')
      ex.description = 'Tính thể tích kim loại'
      ex.version     = '1.0.0'
      ex.copyright   = '2022'
      ex.creator     = 'Quoc Bao'

      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end

    # Nạp lại File extension (main.rb)
    # Để gõ vào Console: TheTich::TheTichKimLoai.reload thì nạp lại Extension này mà không cần
    # khởi động lại Sketchup
    def self.reload
      original_verbose = $VERBOSE
      $VERBOSE = nil
      pattern = File.join(__dir__, '**/*.rb')

      Dir.glob(pattern).each do |file|
        load file
      end.size
    ensure
      $VERBOSE = original_verbose
    end
  end
end

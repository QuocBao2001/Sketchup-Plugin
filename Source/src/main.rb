require 'sketchup'

module TheTich
  module TheTichKimLoai
    # tên các file texture kim loại trong sketchup
    @metalMaterial = ['Aluminum.jpg', 'Metal_Aluminum_Anodized.jpg', 'Metal_Corrogated_Shiny.jpg',
                      'Metal_Embossed.jpg', 'Metal_Rough.jpg', 'Metal_Rusted.jpg', 'Metal_Seamed.jpg',
                      'Metal Silver.jpg', 'Metal_Steel_Textured.jpg', 'Metal_Steel_Textured_White.jpg',
                      'Steel Brushed Stainless.jpg']

    # array lưu danh sách các thực thể bằng kim loại
    @metal_entities = []
    # độ dày của các mặt kim loại
    @thickness_face = 0.1.cm

    # hàm thay đổi độ dày của các mặt khi tính thể tích cho các ống rỗng
    def self.addjust_face_thickness
      # tạo input box với 1 trường nhập liệu
      fields = ['thickness (cm): ']
      defaults = [@thickness_face.to_cm.to_s]
      thickness = UI.inputbox(fields, defaults, 'Addjust face thickness')[0]
      # kiểm tra có phải số thực không, nếu không sẽ yêu cầu người dùng thao tác lại
      if thickness.to_f > 0
        @thickness_face = thickness.to_f.cm
      else
        UI.messagebox('wrong input, please type a positive number in cm!')
        addjust_face_thickness
      end
    end

    # hàm kiểm tra xem người dùng có chọn chỉ 1 component không
    # nếu không sẽ hiển thị thông báo
    def self.check_choose_component
      # Lấy model hiện tại của Sketchup
      @model = Sketchup.active_model
      # lấy đối tượng đang chọn
      @selection = @model.selection
      # các thông báo cho trường hợp không chọn, chọn nhiều, chọn 1 đối tượng không phải component
      if @selection.empty?
        UI.messagebox 'Please select one component before taking action.', MB_OK
      elsif @selection.length > 1
        UI.messagebox 'Please select just one component instance.', MB_OK
      elsif @selection[0].typename != 'ComponentInstance'
        UI.messagebox "You choose a #{@selection[0].typename}, please select a component instead.", MB_OK
      else
        @comIns = @selection[0]
        @comDef = @comIns.definition
        return true
      end
      false
    end

    # Hàm kiểm tra 1 thực thể có phải kim loại không
    def self.check_metal_element(entity)
      return false if entity.material.is_a?(nil::NilClass)
      return false if entity.material.texture.is_a?(nil::NilClass)
      return true if @metalMaterial.include? entity.material.texture.filename

      false
    end

    # hàm tìm tất cả thực thể là kim loại
    def self.find_metal_entities(entity)
      # nếu entity hiện tại có texture là kim loại và là khối đặc thì lưu vào mảng metal_entities
      if check_metal_element(entity) && entity.manifold?
        @metal_entities.push(entity)
      # nếu entity hiện tại là component instance hoặc group thì truy cập đến definition của nó và lấy danh sách entity con
      elsif entity.typename == 'ComponentInstance' || entity.typename == 'Group'
        child_entities = entity.definition.entities
        # duyệt qua các entities con, nếu là component instance hoặc group thì gọi đệ quy
        # nếu không thì kiểm tra phải kim loại không và thêm vào danh sách
        child_entities.each do |child_entity|
          if child_entity.typename == 'ComponentInstance' || child_entity.typename == 'Group'
            find_metal_entities(child_entity)
          elsif child_entity.typename == 'Face' && check_metal_element(child_entity)
            @metal_entities.push(child_entity)
          end
        end
      end
    end

    # hàm tính và trả về bảng tổng kết kết quả tính thể tích
    def self.component_volume_info
      # các biến chuỗi lưu nội dung truyền vào file html
      # các biến số khởi tạo bằng 0 dùng để tính tổng
      volume_solid = ""
      material_solid = ""
      sum_volume_solid = 0
      volume_plate = ""
      material_plate = ""
      sum_volume_plate = 0
      material_volume_dict = {}
      material_material = ""
      material_volume = ""
      sum_material_volume = 0

      # nếu chỉ chọn 1 component thì bắt đầu tính toán
      if check_choose_component
        # clear danh sách các thực thể kim loại của lần chạy trước
        @metal_entities.clear
        # tìm tất cả đối tượng kim loại trong component
        find_metal_entities(@comIns)
        # clear lựa chọn nhằm chọn lại các component kim loại
        @selection.clear
        # chọn tất cả đối tượng kim loại tìm được
        @metal_entities.each do |entity|
          @selection.add(entity)

        end
        # console print for debug
        puts "Number of entities have metal material: #{@selection.length}"
        # duyệt quau tất cả đối tượng
        @selection.each do |entity|
          current_volume = 0
          # nếu là mặt phẳng thì tính thể tích bằng cách nhân với độ dày
          if entity.typename == 'Face'
            current_volume = (entity.area * @thickness_face * 2.54 * 2.54 * 2.54).round(2)
            sum_volume_plate += current_volume
            puts "volume of non solid element: #{current_volume} cm3"
            volume_plate += "<p>#{current_volume} cm3</p>"
            material_plate += "<p>#{entity.material.texture.filename[0..-5]}</p>"
          # nếu là khối đặt thì gọi hàm tính volume
          elsif entity.manifold?
            current_volume = (entity.volume * 2.54 * 2.54 * 2.54).round(2)
            sum_volume_solid += current_volume
            puts "volume #{entity.name}: #{current_volume} cm3"
            volume_solid += "<p>#{current_volume} cm3</p>"
            material_solid += "<p>#{entity.material.texture.filename[0..-5]}</p>"
          end
          # tính toán thể tích cho từng loại kim loại
          if material_volume_dict.has_key? entity.material.texture.filename
            material_volume_dict[entity.material.texture.filename] += current_volume
          else
            material_volume_dict[entity.material.texture.filename] = current_volume
          end
        end

        material_volume_dict.each { |key, value|
          material_material += "<p>#{key[0..-5]}</p>"
          material_volume += "<p>#{value.round(2)} cm3</p>"
          sum_material_volume += value
        }

        # Khởi tạo html dialog để hiển thị nội dung
        dialog = UI::HtmlDialog.new(
          {
            :dialog_title => 'information about volume of selected component',
            :preferences_key => "",
            :resizable => true,
            :width => 1000,
            :height => 600,
            :left => 100,
            :top => 100,
            :min_width => 50,
            :min_height => 50,
            :max_width =>2000,
            :max_height => 2000,
            :style => UI::HtmlDialog::STYLE_DIALOG
          }
        )
  
        # gán đường dẫn đến file html
        dialog.set_file(__dir__ + '/dialog.html')

        # chuyển nội dung sang cho file html
        js_command = "document.getElementById('plate').innerHTML= 'Volume of metal plate with thickness #{@thickness_face * 2.54} cm';"
        js_command += "document.getElementById('solid_volume').innerHTML= '#{volume_solid}';"
        js_command += "document.getElementById('solid_material').innerHTML= '#{material_solid}';"
        js_command += "document.getElementById('plate_volume').innerHTML= '#{volume_plate}';"
        js_command += "document.getElementById('plate_material').innerHTML= '#{material_plate}';"
        js_command += "document.getElementById('sum_solid_volume').innerHTML= '#{sum_volume_solid.round(2)} cm3';"
        js_command += "document.getElementById('sum_plate_volume').innerHTML= '#{sum_volume_plate.round(2)} cm3';"
        js_command += "document.getElementById('material_material').innerHTML= '#{material_material}';"
        js_command += "document.getElementById('material_volume').innerHTML= '#{material_volume}';"
        js_command += "document.getElementById('sum_material_volume').innerHTML= '#{sum_material_volume.round(2)} cm3';"

        num_of_instance = "number of instance of this component: #{@comDef.count_instances}"
        total_volume = "total volume need: #{@comDef.count_instances*sum_material_volume} cm3"
        js_command += "document.getElementById('num_of_instance').innerHTML= '#{num_of_instance} ';"
        js_command += "document.getElementById('total_volume').innerHTML= '#{total_volume} ';"
        dialog.add_action_callback("ready") {
          dialog.execute_script(js_command)
        }
        dialog.show
      end
    end

    #  Khi khởi động 1 file sketchup, hiển thị hướng dẫn cho người dùng và tạo thêm các menu
    unless file_loaded?(__FILE__)

      guide = UI::HtmlDialog.new(
        {
          :dialog_title => 'User guide',
          :preferences_key => "",
          :resizable => true,
          :width => 1000,
          :height => 600,
          :left => 100,
          :top => 100,
          :min_width => 50,
          :min_height => 50,
          :max_width =>2000,
          :max_height => 2000,
          :style => UI::HtmlDialog::STYLE_DIALOG
        }
      )
      guide.set_file(__dir__ + '/user_guide.html')
      guide.show
      menu = UI.menu('Plugins')
      
      # thêm menu tính thể tích
      menu.add_item('calculate metal volume') do
        component_volume_info
      end

      # thêm menu điều chỉnh độ dày các mặt
      menu.add_item('addjust face thickness') do
        addjust_face_thickness
      end

      # thêm menu hiển thị hướng dẫn
      menu.add_item('User guide') do
        guide = UI::HtmlDialog.new(
        {
          :dialog_title => 'User guide',
          :preferences_key => "",
          :resizable => true,
          :width => 1000,
          :height => 600,
          :left => 100,
          :top => 100,
          :min_width => 50,
          :min_height => 50,
          :max_width =>2000,
          :max_height => 2000,
          :style => UI::HtmlDialog::STYLE_DIALOG
        }
      )
      guide.set_file(__dir__ + '/user_guide.html')
      guide.show
      end

      file_loaded(__FILE__)
    end
  end # module HelloCube
end # module Examples

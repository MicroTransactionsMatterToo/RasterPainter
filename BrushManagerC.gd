class_name BrushManagerC
var script_class = "tool"

const LOG_LEVEL = 4
const SHADER_DIR = "shaders/brush_shaders/"

class BrushManager extends Node:
    var Global

    var color: Color setget set_color, get_color
    var _color: Color

    var size: float setget set_size, get_size
    var _size: float = 150

    var endcap setget set_endcap, get_endcap
    var _endcap = Line2D.LINE_CAP_NONE

    var current_brush setget set_brush, get_brush
    var _current_brush_name: String
    

    var _brushes := {}
    var available_brushes = [
        PencilBrush,
        TextureBrush,
        ShadowBrush,
        TerrainBrush,
        EraserBrush
    ]

    signal brush_size_changed(new_size)
    signal brush_color_changed(new_color)
    signal brush_changed()
    signal endcap_style_changed(mode)

    # ===== LOGGING =====
    const LOG_LEVEL = 4

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <BrushManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <BrushManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <BrushManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    # ===== BUILTINS =====
    func _init(global).() -> void:
        logv("init")
        self.Global = global

        for brush_class in self.available_brushes:
            logv("Adding brush %s to available brushes" % brush_class)
            var instance = brush_class.new(self.Global, self)
            logv("Brush Instance %s" % instance)

            self._brushes[instance.brush_name] = instance
            self.add_child(instance)

        self._current_brush_name = "PencilBrush"
        
        var prefs = Global.World.get_meta("painter_config")
        self.set_size(int(prefs.get_c_val("def_size_val")))
        self.set_color(Color(prefs.get_c_val("def_brush_col")))

    func name() -> String:
        return "BrushManager"

    func _to_string():
        return "[BrushManager <Current: %s, NumBrushes: %d]" % [
            self._current_brush_name,
            len(self.available_brushes)
        ]

    func _enter_tree():
        self._current_brush_name = "PencilBrush"

    func _exit_tree():
        self._current_brush_name = "PencilBrush"
        self.queue_free()

    func queue_free() -> void:
        logv("Freeing")
        .queue_free()
    
    # ===== GETTERS/SETTERS =====

    # ---- self.current_brush set/get
    func set_brush(brush_name: String) -> void:
        if self._current_brush_name == brush_name: return
        if self._brushes.has(brush_name):
            self._current_brush_name = brush_name
            self.emit_signal("brush_changed")
        else:
            logd("Brush with name %s not found, ignoring" % brush_name)
    
    func get_brush():
        return self._brushes.get(self._current_brush_name)

    # ---- self.color set/get
    func set_color(color) -> void:
        logv("set_color to %s" % color)
        if color == null: return
        self._color = color
        self.emit_signal("brush_color_changed", self._color)
    
    func get_color() -> Color:
        return self._color

    # ---- self.size set/get
    func set_size(size) -> void:
        logv("set_size to %s" % size)
        if size == null: return
        self._size = size
        Global.World.UI.CursorRadius = self._size
        self.emit_signal("brush_size_changed", self._size)

    func get_size() -> float:
        return self._size

    # ---- self.endcap set/get
    func set_endcap(mode) -> void:
        logv("set endcap to %s" % mode)
        if mode == null: return
        self._endcap = mode
        self.emit_signal("endcap_style_changed", self._endcap)

    func get_endcap():
        return self._endcap

## Brush
# Base class for all brushes
class Brush extends Node2D:
    var Global
    var brushmanager

    var brush_name := "Generic Brush"
    var tooltip := ""
    var icon: Texture

    var ui: Node
    var template: PackedScene

    # ===== LOGGING =====
    const LOG_LEVEL = 4

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <%s>: " % [OS.get_ticks_msec(), self.brush_name])
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <%s>: " % [OS.get_ticks_msec(), self.brush_name])
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <%s>: " % [OS.get_ticks_msec(), self.brush_name])
            print(msg)
        else:
            pass

    # ===== BUILTINS ======

    func _init(global, brush_manager).():
        logv("init")
        self.Global = global
        self.brushmanager = brush_manager
        self.brushmanager.connect("brush_size_changed", self, "set_size")
        self.brushmanager.connect("brush_color_changed", self, "set_color")

    func queue_free():
        if self.ui != null: self.ui.queue_free()
        .queue_free()
    
    func _to_string() -> String:
        return "[Brush \"%s\"]" % self.brush_name

    func get_name() -> String:
        return "%s @ %d" % [self.brush_name, self.get_instance_id()]

    # ===== BRUSH STUFF =====
    func paint(pen, mouse_pos, prev_mouse_pos) -> void:
        pass

    func on_stroke_end() -> void:
        pass

    func on_selected() -> void:
        pass

    # ===== BRUSH UI =====
    func brush_ui():
        logv("Brush default brush_ui called")
        return null

    func hide_ui():
        logv("Default hide_ui called")
        if self.ui != null: self.ui.visible = false

    func show_ui():
        logv("Default show_ui called")
        if self.ui != null: self.ui.visible = true

    # ===== SETTERS =====

    func set_color(color: Color) -> void:
        print("BASE SET COLOR")

    func set_size(size: float) -> void:
        pass

    # ==== UTILS ====
    
    ## ui_config
    # Called to determine which parts of the default brush UI should be shown
    func ui_config() -> Dictionary:
        return {
            "size": true,
            "color": true,
            "endcaps": false
        }


### LineBrush
# Base class for any brush that primarily uses `Line2D` for stroke drawing
class LineBrush extends Brush:
    var Pathway = load("res://scripts/world/objects/Pathway.cs")

    var render_line = Pathway.new(0.0, 0.0, 0.0, 0.0)

    var stroke_line = Line2D.new()
    var stroke_length = 0.0
    var stroke_shader

    var beg_cap = Sprite.new()
    var end_cap = Sprite.new()
    var cap_shader
    var cap_material = ShaderMaterial.new()

    var brush_texture setget set_brush_tex, get_brush_tex
    var _brush_texture

    var use_brush_tex setget set_use_brush_tex, get_use_brush_tex
    var _use_brush_tex = false
    
    var shader_param = null

    var previous_point_drawn: Vector2


    var was_drawing_straight = false
    var painting_state = PaintState.FIRST_POINT

    var debug_line2d = false

    var GridMenu = load("res://scripts/ui/elements/GridMenu.cs")

    var STROKE_THRESHOLD setget , _get_stroke_threshold
    const INTERPOLATE_THRESHOLD: float = 120.0

    enum PaintState {
        FIRST_POINT = 0,
        PAINTING,
        STRAIGHT_STROKE_STARTED,
        STRAIGHT_STROKE,
        STRAIGHT_STROKE_END,
        CLEANUP
    }

    func _init(global, brush_manager).(global, brush_manager):
        self.brushmanager.connect(
            "endcap_style_changed", 
            self,
            "set_endcap"
        )
        self.render_line.Smoothness = 1.0
        return

    # ===== OVERRIDES =====
    func paint(pen, mouse_pos, prev_mouse_pos) -> void:
        if !self.render_line.get_parent() == pen:
            logv("Added stroke_line to pen")
            pen.add_child(self.render_line)
            pen.add_child(self.beg_cap)
            pen.add_child(self.end_cap)

        self.render_line.gradient = null

        # Paint state machine
        match self.painting_state:
            PaintState.FIRST_POINT:
                logv("Drawing first point, ignoring modifiers")
                self.add_stroke_point(mouse_pos)
                self.render_line.visible = true
                self.beg_cap.visible = self.use_brush_tex
                self.end_cap.visible = self.use_brush_tex

                if Input.is_key_pressed(KEY_SHIFT): 
                    self.painting_state = PaintState.STRAIGHT_STROKE_STARTED
                else:
                    self.painting_state = PaintState.PAINTING
            PaintState.PAINTING:
                if not Input.is_mouse_button_pressed(BUTTON_LEFT):
                    logv("BUTTON NOT PRESSED, SHITTING PANTS")
                    self.painting_state = PaintState.CLEANUP

                var debug_points = Array(self.stroke_line.points)
                logv("on stroke end, the last 4 points were: %s" % [debug_points.slice(-4, -1)])
                if self.should_add_point(mouse_pos):
                    self.add_stroke_point(mouse_pos)
                
                if Input.is_key_pressed(KEY_SHIFT): self.painting_state = PaintState.STRAIGHT_STROKE_STARTED
            PaintState.STRAIGHT_STROKE_STARTED:
                logv("STRAIGHT STROKE STARTED")
                self.add_stroke_point(mouse_pos)
                
                self.stroke_line.set_point_position(self.stroke_line.points.size() - 1, mouse_pos)
                
                if Input.is_key_pressed(KEY_SHIFT):
                    self.painting_state = PaintState.STRAIGHT_STROKE
                else:
                    self.painting_state = PaintState.STRAIGHT_STROKE_END
            PaintState.STRAIGHT_STROKE:
                self.stroke_line.set_point_position(self.stroke_line.points.size() - 1, mouse_pos)
                self.render_line.SetEditPoints(Array(self.stroke_line.points))
                self.update_caps(mouse_pos)
                self.previous_point_drawn = mouse_pos

                if Input.is_key_pressed(KEY_SHIFT):
                    self.painting_state = PaintState.STRAIGHT_STROKE
                else:
                    self.painting_state = PaintState.STRAIGHT_STROKE_END
                    self.paint(pen, mouse_pos, prev_mouse_pos)
            PaintState.STRAIGHT_STROKE_END:
                var debug_points = Array(self.stroke_line.points)
                logv("on straight end, the last 4 points were: %s" % [debug_points.slice(-4, -1)])
                self.stroke_line.set_point_position(self.stroke_line.points.size() - 1, mouse_pos)
                self.add_stroke_point(mouse_pos)
                self.previous_point_drawn = mouse_pos

                self.painting_state = PaintState.PAINTING
            PaintState.CLEANUP:
                return
            _:
                self.painting_state = PaintState.PAINTING

        if self.debug_line2d:
            self.stroke_line.antialiased = true
            logv("drawing debug widgets for line2d")
            for index in range(self.render_line.GlobalEditPoints.size()):
                var curr_point = self.render_line.GlobalEditPoints[index]
                pen.draw_circle(curr_point, 15, Color.red)
                if self.render_line.GlobalEditPoints[index + 1] != null:
                    var next_point = self.render_line.GlobalEditPoints[index + 1]
                    var line_dir = curr_point.direction_to(next_point)
                    var line_color = Color(line_dir.x, line_dir.y, 0.0, 1.0)
                    pen.draw_line(
                        curr_point, 
                        next_point,
                        line_color,
                        20
                    )

        
    func set_color(color: Color) -> void:
        self.render_line.default_color = Color(
            color.r,
            color.g,
            color.b,
            1.0
        )

        if self.shader_param != null:
            self.render_line.material.set_shader_param(self.shader_param, color.a)
    
    func set_size(size: float) -> void:
        if size < 1.0: return
        self.render_line.width = size * 2.0
        if self.get_brush_tex() != null:
            logv("UPDATING SIZE")
            var brush_tex_size = self.brush_texture.get_size().y
            var cap_scale = (size * 2) / brush_tex_size
            self.beg_cap.scale = Vector2(cap_scale, cap_scale)
            self.end_cap.scale = Vector2(cap_scale, cap_scale)
        else:
            logv("USING DEFAULT SCALING, brush texture was %s" % self.get_brush_tex())
            var cap_scale = self.render_line.width / 1024
            self.beg_cap.scale = Vector2(cap_scale, cap_scale)
            self.end_cap.scale = Vector2(cap_scale, cap_scale)

    func set_use_brush_tex(val: bool):
        self.beg_cap.visible = val
        self.end_cap.visible = val
        self._use_brush_tex = val

    func get_use_brush_tex():
        return self._use_brush_tex

    func set_brush_tex(tex):
        logv("SETTING BRUSH TEXTURE")
        var brush_tex_size = tex.get_size()
        
        # Clip the given texture to half
        self.beg_cap.texture = tex
        self.beg_cap.centered = true
        self.beg_cap.offset = Vector2(
            -(brush_tex_size.x / 4),
            0
        )
        self.beg_cap.region_rect = Rect2(
            brush_tex_size.x / 2, 0,
            -(brush_tex_size.x / 2),
            brush_tex_size.y
        )
        self.beg_cap.region_enabled = true

        
        self.end_cap.centered = true
        self.end_cap.texture = tex
        self.end_cap.offset = Vector2(
            -(brush_tex_size.x / 4),
            0
        )
        self.end_cap.region_rect = Rect2(
            0, 0,
            brush_tex_size.x / 2,
            brush_tex_size.y
        )
        self.end_cap.region_enabled = true

        self._brush_texture = tex
        self.set_size(self.brushmanager.size)

    func get_brush_tex():
        return self._brush_texture

    func set_endcap(mode):
        logv("endcap_set: %s" % mode)
        if self.ui_config()["endcaps"] != true:
            return
        if mode in [0, 1, 2]:
            self.render_line.end_cap_mode = mode

    func on_stroke_end() -> void:
        self.stroke_line.clear_points()
        self.render_line.visible = false
        self.beg_cap.visible = false
        self.beg_cap.position = Vector2(-100, -100)
        self.end_cap.visible = false
        self.end_cap.position = Vector2(-100, -100)
        self.painting_state = PaintState.FIRST_POINT

    # ===== BRUSH UI =====

    func brush_ui():
        logv("Brush default brush_ui called")
        return null

    func hide_ui():
        logv("Default hide_ui called")
        if self.ui != null: self.ui.visible = false

    func show_ui():
        logv("Default show_ui called")
        if self.ui != null: self.ui.visible = true

    func on_selected() -> void:
        logv("on_selected, cursor_mode: %s" % Global.World.UI.CursorMode)
        Global.World.UI.CursorMode = 5
        Global.World.UI.CursorRadius = self.brushmanager.size

    func ui_config() -> Dictionary:
        return .ui_config()

    # ===== BRUSH SPECIFIC =====
    func add_stroke_point(position: Vector2):
        logv("ADD POINT")
        var point_distance = self.previous_point_drawn.distance_to(position)

        self.stroke_line.add_point(position)
        self.render_line.SetEditPoints(Array(self.stroke_line.points))
            
        self.update_caps(position)
        logv("FUCKER")
        self.stroke_length += point_distance
        self.previous_point_drawn = position

    func should_add_point(position: Vector2) -> bool:
        logv("SHOULD ADD POINT")
        self.render_line.SetEditPoints(Array(self.stroke_line.points))

        if self.previous_point_drawn.distance_to(position) > self.STROKE_THRESHOLD:
            return true
        else:
            self.stroke_line.points[-1] = position
            self.render_line.SetEditPoints(Array(self.stroke_line.points))
            self.update_caps(position)
            return false

    func update_caps(position: Vector2):
        if self.render_line.EditPoints[-2] == null or self.render_line.EditPoints[1] == null:
            logv("no points resetting cap position")
            self.beg_cap.position = position
            self.beg_cap.rotation = 0.0

            self.end_cap.position = position
            self.end_cap.rotation = 0.0
        else:
            self.beg_cap.position = self.render_line.GlobalEditPoints[0].round()
            self.beg_cap.rotation = self.render_line.GlobalEditPoints[1].direction_to(
                self.render_line.GlobalEditPoints[0]
            ).angle()


                
            self.end_cap.position = self.render_line.GlobalEditPoints[-1].round()
            self.end_cap.rotation = self.render_line.EditPoints[-1].direction_to(
                self.render_line.EditPoints[-2]
            ).angle()
            logv("END CAP ROT SET to %s" % self.end_cap.rotation)

    func set_cap_shader_param(key, value):
        self.beg_cap.material.set_shader_param(
            key,
            value
        )
        self.end_cap.material.set_shader_param(
            key,
            value
        )

    func _get_stroke_threshold() -> float:
        return float(self.brushmanager.size / 2)

### PencilBrush
# Brush for solid colors
class PencilBrush extends LineBrush:
    var light_list
    var brush_enable_button

    func _init(global, brush_manager).(global, brush_manager):
        self.icon = load("res://ui/icons/tools/path_tool.png")
        self.brush_name = "PencilBrush"
        self.tooltip = "Pencil"

        self.render_line.texture_mode           = Line2D.LINE_TEXTURE_TILE
        self.render_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        self.render_line.begin_cap_mode         = Line2D.LINE_CAP_ROUND
        self.render_line.end_cap_mode           = Line2D.LINE_CAP_ROUND
        self.render_line.round_precision        = 20
        self.render_line.antialiased            = false
        self.render_line.gradient = null
        self.render_line.name                   = "PencilStroke"
        logv("GOT TO SHADER LOADING")

        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "PencilBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)
        self.render_line.material = ShaderMaterial.new()
        self.render_line.material.shader = self.stroke_shader

        self.cap_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "PencilEndcapShader.shader",
            "Shader",
            true
        )

        self.cap_material.shader = self.cap_shader
        self.beg_cap.material = self.cap_material
        self.end_cap.material = self.cap_material

        self.shader_param = "override_alpha"

    func brush_ui():
        if self.ui == null:
            self.ui = VBoxContainer.new()
            (self.ui as VBoxContainer).size_flags_horizontal = Control.SIZE_EXPAND_FILL
            (self.ui as VBoxContainer).size_flags_vertical = Control.SIZE_EXPAND_FILL

            self.brush_enable_button = Button.new()
            self.brush_enable_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            self.brush_enable_button.toggle_mode = true
            self.brush_enable_button.text = "Use Brush Texture"
            self.brush_enable_button.connect("toggled", self, "_on_brush_toggle")
            self.ui.add_child(self.brush_enable_button)


            self.light_list = GridMenu.new()
            self.light_list.Load("Lights")
            self.light_list.max_columns = 16
            self.light_list.fixed_icon_size = Vector2(64.0, 64.0)
            self.light_list.ShowsPreview = false
            
            self.light_list.size_flags_horizontal = Control.SIZE_FILL
            self.light_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
            self.light_list.connect("item_selected", self, "_on_brush_selected")
            self.ui.add_child(self.light_list)

        return self.ui
    
    func set_color(color):
        .set_color(color)
        self.set_cap_shader_param(
            "brush_color",
            color
        )

    func _on_brush_selected(idx):
        self.render_line.material.set_shader_param(
            "brush_tex",
            self.light_list.Selected
        )
        .set_brush_tex(self.light_list.Selected)
        self.brush_enable_button.pressed = true
    
    func _on_brush_toggle(pressed):
        logv("brush toggled")
        self.use_brush_tex = pressed
        self.render_line.material.set_shader_param(
            "brush_tex_enabled",
            pressed
        )

    func ui_config() -> Dictionary:
        return {
            "size": true,
            "color": true,
            "opacity": true,
            "palette": "pencilbrush_palette",
            "endcaps": false
        }

### TextureBrush
# Brush for drawing lines of any loaded asset
class TextureBrush extends LineBrush:
    var path_grid_menu = null
    
    func _init(global, brush_manager).(global, brush_manager):
        self.icon = load("res://ui/icons/tools/material_brush.png")
        self.brush_name = "TextureBrush"
        self.tooltip = "Texture Brush"

        self.render_line.texture_mode           = Line2D.LINE_TEXTURE_TILE
        self.render_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        self.render_line.antialiased            = false
        self.render_line.name                   = "TextureStroke"

        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "TextureBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)
        self.render_line.material = ShaderMaterial.new()
        self.render_line.material.shader = self.stroke_shader

        self.shader_param = "alpha_mult"

    # ===== BRUSH SPECIFIC ======
    func set_texture(texture: Texture) -> void:
        self.render_line.texture = texture

    func on_texture_selected(idx):
        self.set_texture(self.path_grid_menu.Selected)

    # ===== UI =====
    func brush_ui():
        logv("TextureBrush ui called")
        if self.ui == null:
            self.ui = VBoxContainer.new()
            (self.ui as VBoxContainer).size_flags_vertical = VBoxContainer.SIZE_EXPAND_FILL
            (self.ui as VBoxContainer).size_flags_horizontal = VBoxContainer.SIZE_EXPAND_FILL
            logv("TextureBrush create UI")

        if self.path_grid_menu == null:
            var GridMenu = load("res://scripts/ui/elements/GridMenu.cs")

            self.path_grid_menu = GridMenu.new()
            self.path_grid_menu.Load("Paths")

            self.path_grid_menu.max_columns = 1
            self.path_grid_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            self.path_grid_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
            self.path_grid_menu.ShowsPreview = true

            self.path_grid_menu.connect(
                "item_selected",
                self,
                "on_texture_selected"
            )

            self.path_grid_menu.rect_size = Vector2(100, 300)

            self.path_grid_menu.select(0, true)
            
            self.ui.add_child(self.path_grid_menu)
            logv("TextureBrush grid menu")

            self.set_texture(self.path_grid_menu.Selected)
        
        return self.ui

    func ui_config() -> Dictionary:
        return {
            "size": true,
            "color": false,
            "opacity": true,
            "endcaps": false
        }

class ShadowBrush extends LineBrush:
    var transition_in: HSlider
    var transition_out: HSlider
    var offset: HSlider
    var alpha_invert: CheckButton
    var preview_control: Control
    var preview_line: Line2D

    # ===== BUILTINS =====
    func _init(global, brush_manager).(global, brush_manager) -> void:
        self.icon = load("res://ui/icons/tools/light_tool.png")
        self.brush_name = "ShadowBrush"
        self.tooltip = "Dynamic Shadow Brush"

        self.render_line.texture_mode           = Line2D.LINE_TEXTURE_STRETCH
        self.render_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        self.render_line.round_precision        = 20
        self.render_line.antialiased            = false
        self.render_line.name                   = "ShadowBrushLine2D"

        self.stroke_line.texture_mode           = Line2D.LINE_TEXTURE_STRETCH
        self.stroke_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        self.stroke_line.round_precision        = 20
        self.stroke_line.antialiased            = false
        

        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "ShadowBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)

        self.render_line.material = ShaderMaterial.new()
        self.render_line.material.shader = self.stroke_shader

        self.shader_param = "alpha_mult"

    # ===== BRUSH UI =====
    func brush_ui():
        logv("ShadowBrush UI called")
        if self.ui == null:
            var template = ResourceLoader.load(Global.Root + "ui/brushes/shadow_brush_ui.tscn", "", true)

            self.ui = template.instance()

            self.preview_control = self.ui.get_node("LinePreview")
            self.preview_line = self.stroke_line.duplicate()
            self.preview_line.material = self.render_line.material
            self.preview_line.antialiased = false
            self.preview_line.width = 50
            var preview_center = self.preview_control.rect_size / 2
            var preview_transform = self.preview_control.get_canvas_transform()
            var preview_coords = [
                Vector2(0.0, preview_center.y),
                Vector2(self.preview_control.rect_size.x, preview_center.y)
            ]
            logv("Container Size: %s" % self.preview_control.rect_size)
            logv("Mid X,Y: %d, %d" % [preview_center, self.preview_control.rect_size.x / 2])
            self.preview_control.add_child(self.preview_line)
            self.preview_line.add_point(preview_coords[0])
            self.preview_line.add_point(preview_coords[1])

            # self.preview_line.material = self.stroke_line.material


            self.transition_in = self.ui.get_node("Transition/In/InSlider")
            self.transition_in.connect(
                "value_changed",
                self,
                "_on_transition_in_val"
            )
            self.ui.get_node("Transition/In/InBox").share(self.transition_in)

            self.transition_out = self.ui.get_node("Transition/Out/OutSlider")
            self.transition_out.connect(
                "value_changed",
                self,
                "_on_transition_out_val"
            )
            self.ui.get_node("Transition/Out/OutBox").share(self.transition_out)

            self.offset = self.ui.get_node("Offset/OffsetVal")
            self.offset.connect(
                "value_changed",
                self,
                "_on_y_offset_val"
            )

            self.alpha_invert = self.ui.get_node("FlipAlpha/CheckButton")
            self.alpha_invert.connect(
                "toggled",
                self,
                "_on_flip_alpha"
            )

        return self.ui

    # ===== OVERRIDES =====
    func show_ui():
        .show_ui()

        yield(get_tree(), "idle_frame")
        logv("updating shadow preview")
        var updated_x_end = self.preview_control.rect_size.x
        var updated_y_center = self.preview_control.rect_size.y / 2
        self.preview_line.set_point_position(0, Vector2(0, updated_y_center))
        self.preview_line.set_point_position(1, Vector2(updated_x_end, updated_y_center))

    func paint(pen, mouse_pos, prev_mouse_pos):
        self.render_line.texture_mode           = Line2D.LINE_TEXTURE_STRETCH
        .paint(pen, mouse_pos, prev_mouse_pos)

    func ui_config() -> Dictionary:
        return {
            "size": true,
            "color": true,
            "endcaps": false,
            "opacity": true
        }
    
    # ===== SIGNAL HANDLERS =====
    func on_stroke_end():
        .on_stroke_end()

    func set_color(color: Color) -> void:
        .set_color(color)
        self.render_line.default_color = color
        self.preview_line.default_color = self.render_line.default_color

    func _on_transition_in_val(val: float):
        logv("transition_in val changed %d" % val)
        self.render_line.material.set_shader_param("transition_in_start", val)
        self.render_line.material.set_shader_param("transition_in", val != 0.0)

    func _on_transition_out_val(val: float):
        logv("transition_out val changed %d" % val)
        self.render_line.material.set_shader_param("transition_out_start", val)
        self.render_line.material.set_shader_param("transition_out", val != 1.0)

    func _on_flip_alpha(val: bool):
        logv("invert_alpha val changed: %d" % val)
        self.render_line.material.set_shader_param("invert_alpha", val)
    
    func _on_y_offset_val(val: float):
        logv("y_offset val changed: %d" % val)
        self.render_line.material.set_shader_param("y_offset", val)


class TerrainBrush extends LineBrush:
    var terrain_list
    var selected_index = 0
    var terrain_initialised = false

    var light_list
    var selected_light = 0

    var updating_flag = false
    var brush_enable_button
    

    func _init(global, brush_manager).(global, brush_manager):
        self.icon = load("res://ui/icons/tools/terrain_brush.png")
        self.brush_name = "TerrainBrush"
        self.tooltip = "Terrain Brush"

        self.render_line.texture_mode           = Line2D.LINE_TEXTURE_STRETCH
        # self.render_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        # self.render_line.end_cap_mode           = Line2D.LINE_CAP_ROUND
        # self.render_line.begin_cap_mode         = Line2D.LINE_CAP_ROUND
        self.render_line.antialiased            = false
        self.render_line.name                   = "TerrainStroke"

        self.render_line.default_color = Color(1, 1, 1, 1.0)

        self.shader_param = "alpha_mult"

        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "TerrainBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)
        self.render_line.material = ShaderMaterial.new()
        self.render_line.material.shader = self.stroke_shader
        self.render_line.material.set_shader_param(
            "terrain_tex",
            Global.World.Level.Terrain.Textures[1]
        )

        self.cap_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "TerrainCapShader.shader",
            "Shader",
            true
        ).duplicate(false)
        
        self.beg_cap.material = ShaderMaterial.new()
        self.beg_cap.material.shader = self.cap_shader
        self.end_cap.material = ShaderMaterial.new()
        self.end_cap.material.shader = self.cap_shader

        

    func brush_ui():
        if self.ui == null:
            self.ui = VBoxContainer.new()
            (self.ui as VBoxContainer).size_flags_horizontal = Control.SIZE_EXPAND_FILL
            (self.ui as VBoxContainer).size_flags_vertical = Control.SIZE_EXPAND_FILL

            self.brush_enable_button = Button.new()
            self.brush_enable_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            self.brush_enable_button.toggle_mode = true
            self.brush_enable_button.text = "Use Brush Texture"
            self.brush_enable_button.connect("toggled", self, "_on_brush_toggle")
            self.ui.add_child(self.brush_enable_button)


            self.light_list = GridMenu.new()
            self.light_list.Load("Lights")
            self.light_list.max_columns = 16
            self.light_list.fixed_icon_size = Vector2(64.0, 64.0)
            self.light_list.ShowsPreview = false
            
            self.light_list.size_flags_horizontal = Control.SIZE_FILL
            self.light_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
            self.light_list.connect("item_selected", self, "_on_brush_selected")
            self.ui.add_child(self.light_list)
            
            self.terrain_list = ItemList.new()
            self.terrain_list.fixed_icon_size = Vector2(50, 50)
            self.terrain_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
            self.terrain_list.size_flags_horizontal = Control.SIZE_FILL
            self.ui.add_child(self.terrain_list)

            self.terrain_list.connect("item_selected", self, "_on_item_select")

        return self.ui

    func paint(pen, mouse_pos, prev_mouse_pos):
        self.render_line.material.set_shader_param(
            "pathway_transform",
            self.render_line.transform
        )
        .paint(pen, mouse_pos, prev_mouse_pos)
        self.beg_cap.material.set_shader_param(
            "sprite_transform",
            self.beg_cap.transform
        )
        self.end_cap.material.set_shader_param(
            "sprite_transform",
            self.end_cap.transform
        )

    func show_ui():
        logv("Showing ui, texture list: %s" % [Global.World.Level.Terrain.Textures])
        Global.Editor.Tools["TerrainBrush"].SetControlsForExpandedSlots(
            Global.Editor.Tools["TerrainBrush"].extendedTerrainTypes
        )
        self.terrain_list.clear()
        
        # Janky workaround because this is the only good way to get the name of the current terrain textures
        if not self.terrain_initialised and not self.updating_flag:
            self.updating_flag = true
            Global.Editor.Toolset.Quickswitch("TerrainBrush")
            Global.Editor.Toolset.Quickswitch("RasterPainter")
            self.terrain_initialised = true
        
        self.update_terrains()
        if self.selected_index > self.terrain_list.get_item_count():
            self.selected_index = 0
        
        self.terrain_list.select(self.selected_index)
        self.terrain_list.emit_signal("item_selected", self.selected_index)
        
        .show_ui()

    func update_terrains():
        if not self.terrain_initialised:
            return

        self.terrain_list.clear()
        var texture_count = 8 if Global.World.Level.Terrain.ExpandedSlots else 4
        Global.Editor.Tools["TerrainBrush"].ExpandSlots(Global.World.Level.Terrain.ExpandedSlots)
        logv("Terrain Texture count: %s" % texture_count)
        for i in range(0, Global.Editor.Tools["TerrainBrush"].terrainList.get_item_count()):
            var terrain_name = Global.Editor.Tools["TerrainBrush"].terrainList.get_item_text(i)
            var thumbnail = Global.Editor.Tools["TerrainBrush"].terrainList.get_item_icon(i)
            logv("Got %s for %s" % [terrain_name, i])
            self.terrain_list.add_item(
                terrain_name,
                thumbnail
            )
            self.terrain_list.set_item_metadata(i, Global.World.Level.Terrain.Textures[i])

    func set_color(color):
        .set_color(color)
        self.set_cap_shader_param("alpha_mult", color.a)

    func _on_brush_selected(idx):
        self.render_line.material.set_shader_param(
            "brush_tex",
            self.light_list.Selected
        )
        .set_brush_tex(self.light_list.Selected)
        self.brush_enable_button.pressed = true
    
    func _on_brush_toggle(pressed):
        logv("brush toggled")
        self.use_brush_tex = pressed
        self.render_line.material.set_shader_param(
            "brush_tex_enabled",
            pressed
        )

    func _on_item_select(idx):
        self.render_line.material.set_shader_param(
            "terrain_tex", 
            self.terrain_list.get_item_metadata(idx)
        )
        self.set_cap_shader_param(
            "terrain_tex",
            self.terrain_list.get_item_metadata(idx)
        )
        self.selected_index = idx



    func ui_config() -> Dictionary:
        return {
            "size": true,
            "color": false,
            "endcaps": false,
            "opacity": true
        }

class EraserBrush extends LineBrush:
    var clear_button
    func _init(global, brush_manager).(global, brush_manager):
        var icon = ImageTexture.new()
        icon.load(Global.Root + "icons/eraser.png")
        self.icon = icon
        self.brush_name = "EraserBrush"
        self.tooltip = "Eraser"

        self.render_line.texture_mode           = Line2D.LINE_TEXTURE_TILE
        self.render_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        self.render_line.end_cap_mode           = Line2D.LINE_CAP_ROUND
        self.render_line.begin_cap_mode         = Line2D.LINE_CAP_ROUND
        self.render_line.antialiased            = false
        self.render_line.name                   = "EraserStroke"

        var background_texture := ImageTexture.new()
        background_texture.load(Global.Root + "icons/preview_background.png")
        self.render_line.texture = background_texture
        self.stroke_line.default_color = Color(1, 1, 1, 0.75)


        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "EraserBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)
        self.render_line.material = ShaderMaterial.new()
        self.render_line.material.shader = self.stroke_shader

    func paint(pen, mouse_pos, prev_mouse_pos):
        .paint(pen, mouse_pos, prev_mouse_pos)

    func brush_ui():
        if self.ui == null:
            self.ui = VBoxContainer.new()
            (self.ui as VBoxContainer).size_flags_horizontal = Control.SIZE_EXPAND_FILL
            (self.ui as VBoxContainer).size_flags_vertical = Control.SIZE_EXPAND_FILL
            
            self.clear_button = Button.new()
            self.clear_button.text = "Clear Current Layer"
            self.clear_button.connect("pressed", self, "_on_clear_pressed")
            
            self.ui.add_child(self.clear_button)

        return self.ui

    func _on_clear_pressed():
        logv("Clear pressed")
        var scontrol = Global.World.get_meta("RasterControl")
        var clear_image = scontrol.active_layer.texture.get_data()
        logv("Got layer texture: %s" % clear_image)
        clear_image.fill(Color(0.0, 0.0, 0.0, 0.0))
        logv("Filled layer with nil")
        scontrol.active_layer.texture.set_data(clear_image)
        scontrol.active_layer.texture = scontrol.active_layer.texture
        logv("Wrote back")


    func set_color(color):
        pass

    func ui_config() -> Dictionary:
        return {
            "size": true,
            "color": false,
            "endcaps": false,
            "opacity": false
        }
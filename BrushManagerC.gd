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

    var current_brush setget set_brush, get_brush
    var _current_brush_name: String

    var _brushes := {}
    var available_brushes = [
        PencilBrush,
        TextureBrush,
        ShadowBrush
    ]

    signal brush_size_changed(new_size)
    signal brush_color_changed(new_color)
    signal brush_changed()

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

        print(self.available_brushes)

        for brush_class in self.available_brushes:
            logv("Adding brush %s to available brushes" % brush_class)
            var instance = brush_class.new(self.Global, self)
            logv("Brush Instance %s" % instance)

            self._brushes[instance.brush_name] = instance
            self.add_child(instance)

        self._current_brush_name = self._brushes.values()[0].brush_name

            

    func name() -> String:
        return "BrushManager"

    func _to_string():
        return "[BrushManager <Current: %s, NumBrushes: %d]" % [
            self._current_brush_name,
            len(self.available_brushes)
        ]

    func queue_free() -> void:
        logv("Freeing")
        .queue_free()
    
    # ===== GETTERS/SETTERS =====

    # ---- self.current_brush set/get
    func set_brush(brush_name: String) -> void:
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
        self.emit_signal("brush_size_changed", self._size)

    func get_size() -> float:
        return self._size

class Brush extends Node2D:
    var Global
    var brushmanager

    var brush_name := "Generic Brush"
    var icon: Texture

    var ui: Node
    var template: PackedScene

    # ===== LOGGING =====
    const LOG_LEVEL = 4

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <Brush>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <Brush>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <Brush>: " % OS.get_ticks_msec())
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


### LineBrush
# Base class for any brush that primarily uses `Line2D` for stroke drawing
class LineBrush extends Brush:
    var stroke_line: Line2D = Line2D.new()
    var stroke_shader
    
    var shader_param = null

    var previous_point_drawn: Vector2

    const STROKE_THRESHOLD: float = 20.0

    func _init(global, brush_manager).(global, brush_manager):
        return

    # ===== OVERRIDES =====
    func paint(pen, mouse_pos, prev_mouse_pos) -> void:
        if !self.stroke_line.get_parent() == pen:
            logv("Added stroke_line to pen")
            pen.add_child(self.stroke_line)
        
        if len(self.stroke_line.points) == 0:
            logv("No points in stroke line, ignoring any modifiers")
            self.stroke_line.add_point(mouse_pos)
        
        if Input.is_key_pressed(KEY_SHIFT):
            logv("SHIFT is pressed, making a straight line")
            if len(self.stroke_line.points) == 1: self.add_stroke_point(mouse_pos)
            else: 
                self.stroke_line.set_point_position(self.stroke_line.points.size() - 1, mouse_pos)
                self.previous_point_drawn = mouse_pos
            
            return

        if self.should_add_point(mouse_pos):
            self.add_stroke_point(mouse_pos)
        
    func set_color(color: Color) -> void:
        self.stroke_line.default_color = Color(
            color.r,
            color.g,
            color.b,
            1.0
        )

        self.stroke_line.material.set_shader_param(self.shader_param, color.a)
    
    func set_size(size: float) -> void:
        if size < 1.0: return
        self.stroke_line.width = size * 2.0

    func on_stroke_end() -> void:
        self.stroke_line.clear_points()

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

    # ===== BRUSH SPECIFIC =====
    func add_stroke_point(position: Vector2):
        self.stroke_line.add_point(position)
        self.previous_point_drawn = position

    func should_add_point(position: Vector2) -> bool:
        return self.previous_point_drawn.distance_to(position) > STROKE_THRESHOLD

### PencilBrush
# Brush for solid colors
class PencilBrush extends LineBrush:
    func _init(global, brush_manager).(global, brush_manager):
        self.icon = load("res://ui/icons/tools/path_tool.png")
        self.brush_name = "PencilBrush"

        self.stroke_line.texture_mode           = Line2D.LINE_TEXTURE_STRETCH
        self.stroke_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        self.stroke_line.antialiased            = false
        self.stroke_line.name                   = "PencilStroke"

        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "PencilBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)
        self.stroke_line.material = ShaderMaterial.new()
        self.stroke_line.material.shader = self.stroke_shader

        self.shader_param = "override_alpha"

### TextureBrush
# Brush for drawing lines of any loaded asset
class TextureBrush extends LineBrush:
    var path_grid_menu = null
    func _init(global, brush_manager).(global, brush_manager):
        self.icon = load("res://ui/icons/material_brush.png")
        self.brush_name = "TextureBrush"

        self.stroke_line.texture_mode           = Line2D.LINE_TEXTURE_STRETCH
        self.stroke_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        self.stroke_line.antialiased            = false
        self.stroke_line.name                   = "TextureStroke"

        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "TextureBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)
        self.stroke_line.material = ShaderMaterial.new()
        self.stroke_line.material.shader = self.stroke_shader

        self.shader_param = "alpha_mult"

    # ===== BRUSH SPECIFIC ======
    func set_texture(texture: Texture) -> void:
        self.stroke_line.texture = texture

    func on_texture_selected(idx):
        self.set_texture(self.path_grid_menu.Selected)

    # ===== UI =====
    func brush_ui():
        if self.ui == null:
            self.ui = VBoxContainer.new()
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

            self.path_grid_menu.select(0, true)
            
            self.ui.add_child(self.path_grid_menu)
            logv("TextureBrush grid menu")
        
        return self.ui

class ShadowBrush extends LineBrush:
    func _init(global, brush_manager).(global, brush_manager) -> void:
        self.icon = load("res://ui/icons/tools/light_tool.png")
        self.brush_name = "ShadowBrush"

        self.stroke_line.texture_mode       = Line2D.LINE_TEXTURE_TILE
        self.stroke_line.antialiased        = false
        self.stroke_line.joint_mode         = Line2D.LINE_JOINT_SHARP
        self.stroke_line.name               = "ShadowBrushLine2D"

        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "ShadowBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)

        self.stroke_line.material = ShaderMaterial.new()
        self.stroke_line.material.shader = self.stroke_shader

        self.shader_param = "alpha_mult"
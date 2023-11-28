class_name BrushManagerC
var script_class = "tool"

const LOG_LEVEL = 0
const SHADER_DIR = "shaders/brush_shaders/"

class BrushManager extends Node:

    var Global

    var color: Color setget set_color, get_color
    var _color: Color
    var size: float setget set_size, get_size
    var _size: float = 300
    var _strength: float

    var _brush_buttons

    var _tool_panel

    var current_brush setget set_brush, get_brush
    var _current_brush_name: String

    var _brushes: Dictionary = {}
    var _available_brushes = [
        Pencil,
        TextureBrush,
        ShadowBrush
    ]

    func _init(tool_panel).() -> void:
        self.name = "BrushManager"
        self._tool_panel = tool_panel
        self._brush_buttons = ButtonGroup.new()

    func _ready() -> void:
        logi("Brush Manager initialised")

        for brush_class in self._available_brushes:
            var instance = brush_class.new(self.Global)

            var brush_button = Button.new()
            brush_button.icon = instance.icon
            brush_button.set_meta("brush_name", instance.brush_name)
            brush_button.group = self._brush_buttons
            brush_button.toggle_mode = true

            var brush_selector = self._tool_panel.get_node("PanelRoot/BrushControls/BrushSelector")
            brush_selector.add_child(brush_button)

            self._brushes[instance.brush_name] = instance
            logv("Added brush {name} to available brushes".format({
                "name": instance.brush_name
            }))
            print(self._brushes)
            self.add_child(instance)

        self._brush_buttons.connect(
            "pressed",
            self,
            "_on_brushbutton"
        )
        self._brush_buttons.get_buttons()[0].set_pressed_no_signal(true)
        self.set_size(300)

        self._ui_setup()

        

        self._current_brush_name = self._brushes.values()[0].brush_name

    func queue_free() -> void:
        print("[BrushManager]: Freeing")
        .queue_free()
    
    func _ui_setup() -> void:
        var brush_size_c = self._tool_panel.get_node("PanelRoot/BrushControls/BrushSettings/BSizeC/BSize")
        var brush_size_slider: HSlider = brush_size_c.get_node("HSlider")
        var brush_size_spinbox: SpinBox = brush_size_c.get_node("SpinBox")

        brush_size_slider.share(brush_size_spinbox)
        brush_size_slider.connect(
            "value_changed",
            self,
            "set_size"
        )

        var brush_color_pallete = self._tool_panel.get_node("PanelRoot/BrushControls/BrushSettings/BColorC/BrushPalette")
        brush_color_pallete.connect(
            "color_changed",
            self,
            "set_color"
        )

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("[V] BM: ")
            print(msg)
        else:
            pass

    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("[I] BM: ")
            print(msg)
        else:
            pass

    func get_brush() -> Brush:
        return self._brushes.get(self._current_brush_name)

    func set_brush(brush_name: String) -> void:
        if self._brushes.has(brush_name):
            self._current_brush_name = brush_name
            if (self._tool_panel != null):
                self.clear_brush_ui()
                self.get_brush().brush_ui(self._tool_panel)

    func clear_brush_ui():
        var brush_ui = self._tool_panel.get_node("PanelRoot/BrushUI")
        for child in brush_ui.get_children():
            brush_ui.remove_child(child)

    func set_color(color) -> void:
        self._color = color
        for brush in self._brushes.values():
            brush.set_color(color)

    func get_color() -> Color:
        return self._color

    func set_size(size) -> void:
        self._size = size
        for brush in self._brushes.values():
            brush.set_size(size)

    func get_size() -> float:
        return self._size

    func set_toolpanel(panel):
        self._tool_panel = panel
        self.get_brush().brush_ui(self._tool_panel)

    func _on_brushbutton(button):
        logv("Brush changed to " + str(button.get_meta("brush_name")))
        self.set_brush(button.get_meta("brush_name"))


class Brush extends Node2D:
    var size: float = 300
    var color: Color = Color.red
    var icon: Texture
    var brush_name: String = "Generic Brush"

    var Global
    var World
    var WorldUI

    func _init(global):
        self.World = global.World
        self.WorldUI = global.WorldUI
        self.Global = global

    


    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("[V] BR: ")
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("[I] B: ")
            print(msg)
        else:
            pass

    func paint(pen: Node2D, mouse_pos: Vector2, prev_mouse_pos: Vector2) -> void:
        print("Raw Brush Called")

    func brush_ui(ui_root):
        logv("YOEP")
        return

    func _to_string() -> String:
        return "[Brush <Name: {name}>]".format({
            "name": self.brush_name
        })

class Pencil extends Brush:
    var stroke_line = Line2D.new()
    var line_added = false
    var line_shader

    func _init(global).(global) -> void:
        self.icon = load("res://ui/icons/tools/cave_brush.png")
        self.brush_name = "Pencil"
        self.name = "PencilBrush @" + str(self.get_instance_id())
        
        self.stroke_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
        self.stroke_line.antialiased = false
        self.stroke_line.material.blend_mode = CanvasItem.BLEND_MODE_DISABLED
        self.stroke_line.joint_mode = Line2D.LINE_JOINT_ROUND
        self.stroke_line.name = "PenLine2D"

        self.line_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "PencilBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)

        self.stroke_line.material = ShaderMaterial.new()
        self.stroke_line.material.shader = self.line_shader

    func paint(pen: Node2D, mouse_pos: Vector2, prev_mouse_pos: Vector2) -> void:
        if !self.line_added:
            pen.get_parent().add_child(self.stroke_line)
            self.line_added = true
        
        if len(stroke_line.points) > 1:
            if stroke_line.points[-1].distance_to(mouse_pos) < 20.0:
                return
        
        self.stroke_line.add_point(mouse_pos)

    func set_size(size: float) -> void:
        if size < 1:
            return
        
        self.size = size
        self.stroke_line.width = size * 2
    
    func set_color(ncolor) -> void:
        self.color = ncolor
        self.color.a = 1.0

        self.stroke_line.default_color = self.color
        self.stroke_line.material.set_shader_param("override_alpha", ncolor.a)

    func on_stroke_end() -> void:
        self.stroke_line.clear_points()
    
    func on_select() -> void:
        WorldUI.CursorMode = 5
        WorldUI.CursorRadius = self.size

    func brush_ui(ui_root):
        return

class TextureBrush extends Brush:
    var stroke_asset = load("res://textures/paths/stairs_stone_2.png") 
    var stroke_texture
    var stroke_line = Line2D.new()
    var line_added = false
    var line_shader
    var line_mat
    var path_grid
    var test_rect
    var test_rect2

    func _init(global).(global) -> void:
        self.icon = load("res://ui/icons/tools/cave_brush.png")
        self.brush_name = "TextureBrush"
        self.name = "TextureBrush @" + str(self.get_instance_id())

        self.stroke_line.texture_mode = Line2D.LINE_TEXTURE_TILE
        self.stroke_line.antialiased = false
        self.stroke_line.joint_mode = Line2D.LINE_JOINT_ROUND
        self.stroke_line.name = "TextureLine2D"


        self.line_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "TextureBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)
        self.line_mat = ShaderMaterial.new()
        self.line_mat.shader = self.line_shader

        self.stroke_texture = self.stroke_asset

        self.stroke_line.material = self.line_mat
        self.stroke_line.texture = self.stroke_texture

    func paint(pen: Node2D, mouse_pos: Vector2, prev_mouse_pos: Vector2) -> void:
        if !self.line_added:
            pen.add_child(self.stroke_line)
            self.line_added = true
        
        if len(stroke_line.points) > 1:
            if stroke_line.points[-1].distance_to(mouse_pos) < 20.0:
                return
        
        self.stroke_line.add_point(mouse_pos)

    func set_size(size: float) -> void:
        if size < 1:
            return
        
        self.size = size
        self.stroke_line.width = size * 2
    
    func set_color(ncolor) -> void:
        self.color = ncolor
        self.color.a = 1.0

        self.stroke_line.default_color = self.color
        self.stroke_line.material.set_shader_param("alpha_mult", ncolor.a)

    func set_texture(idx):
        logv("Set TextureBrush texture: " + str(idx))
        var texture = self.path_grid.Selected

        self.stroke_line.texture = texture


    func on_stroke_end() -> void:
        self.stroke_line.clear_points()
    
    func on_select() -> void:
        WorldUI.CursorMode = 5
        WorldUI.CursorRadius = self.size

    func brush_ui(ui_root):
        var panel_root = ui_root.get_node("PanelRoot")
        var brush_ui = panel_root.get_node("BrushUI")
        logv(panel_root)
        if self.path_grid == null:
            var GridMenu = load("res://scripts/ui/elements/GridMenu.cs")
            self.path_grid = GridMenu.new()

            self.path_grid.Load("Paths")
            self.path_grid.max_columns = 1;
            self.path_grid.ShowsPreview = true
            self.path_grid.select(0, true)
            self.path_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            self.path_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
            logv(self.path_grid.OnTextureSelected)

            self.path_grid.connect(
                "item_selected",
                self,
                "set_texture"
            )

        brush_ui.add_child(self.path_grid)

class ShadowBrush extends Brush:
    var stroke_line = Line2D.new()
    var line_added = false
    var line_shader

    func _init(global).(global) -> void:
        self.icon = load("res://ui/icons/tools/cave_brush.png")
        self.brush_name = "Shadow"
        self.name = "ShadowBrush @" + str(self.get_instance_id())

        self.stroke_line.texture_mode = Line2D.LINE_TEXTURE_TILE
        self.stroke_line.antialiased = false
        self.stroke_line.material.blend_mode = CanvasItem.BLEND_MODE_DISABLED
        self.stroke_line.joint_mode = Line2D.LINE_JOINT_SHARP
        self.stroke_line.name = "PenLine2D"

        self.line_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "ShadowBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)

        self.stroke_line.material = ShaderMaterial.new()
        self.stroke_line.material.shader = self.line_shader

    func paint(pen: Node2D, mouse_pos: Vector2, prev_mouse_pos: Vector2) -> void:
        if !self.line_added:
            pen.get_parent().add_child(self.stroke_line)
            self.line_added = true
        
        if len(stroke_line.points) > 1:
            if stroke_line.points[-1].distance_to(mouse_pos) < 20.0:
                var recent_point = (self.stroke_line.get_point_count() - 1)
                self.stroke_line.set_point_position(recent_point, mouse_pos)
                return

        
        self.stroke_line.add_point(mouse_pos)

    func set_size(size: float) -> void:
        if size < 1:
            return
        
        self.size = size
        self.stroke_line.width = size * 2
    
    func set_color(ncolor) -> void:
        self.color = ncolor
        self.color.a = 1.0

        self.stroke_line.default_color = self.color
        self.stroke_line.material.set_shader_param("override_alpha", ncolor.a)

    func on_stroke_end() -> void:
        self.stroke_line.clear_points()
    
    func on_select() -> void:
        WorldUI.CursorMode = 5
        WorldUI.CursorRadius = self.size

    func brush_ui(ui_root):
        pass
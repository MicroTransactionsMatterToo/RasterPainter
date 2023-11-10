class_name BrushManagerC
var script_class = "tool"

const LOG_LEVEL = 4

class BrushManager extends Node:

    var Global

    var color: Color setget set_color, get_color
    var _color: Color
    var size: float setget set_size, get_size
    var _size: float
    var _strength: float

    var current_brush setget set_brush, get_brush
    var _current_brush_name: String

    var _brushes: Dictionary = {}
    var _available_brushes = [
        Pencil
    ]

    func _init().() -> void:
        self.name = "BrushManager"

    func _ready() -> void:
        logi("Brush Manager initialised")
        logi(Pencil)
        for brush_class in self._available_brushes:
            var instance = brush_class.new(self.Global)
            printraw("FUCK: ")
            print(instance)
            self._brushes[instance.brush_name] = instance
            logv("Added brush {name} to available brushes".format({
                "name": instance.brush_name
            }))
            print(self._brushes)
            self.add_child(instance)
        self._current_brush_name = self._brushes.values()[0].brush_name


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

class Brush extends Node2D:
    var size: float = 50
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

       self.line_shader = ResourceLoader.load(Global.Root + "ShadowLayer.shader", "Shader", true).duplicate(false)

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
        logv("Set alpha to " + str(ncolor.a))
        logv(self.material)
        self.stroke_line.material.set_shader_param("override_alpha", ncolor.a)

    func on_stroke_end() -> void:
        self.stroke_line.clear_points()
    
    func on_select() -> void:
        WorldUI.CursorMode = 5
        WorldUI.CursorRadius = self.size
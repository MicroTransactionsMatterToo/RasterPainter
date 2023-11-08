class_name ShadowPainter
var script_class = "tool"



var shadow_layers: Dictionary = {}
var shadow_control
var root_canvas: CanvasLayer
var control: ShadowCanvasPainter
var ui_skeleton
var ui_instance


var _enabled = false
var _tool_panel

var _ui_root
var _size_slider
var _strength_slider
var _colorbox
var _brushbox

var _brush_color: Color
var _brush_size: float
var _brush_strength: float
var _brush_selected: String
var _brushes = {
    "Pencil": Pencil.new()
}


const DEBUG = true

func debugp(msg):
    if DEBUG:
        printraw("SPD: ")
        print(msg)
    else:
        pass

func start() -> void:
    debugp("ShadowPainter loaded")
    debugp("Getting root canvas")
    root_canvas = Global.Editor
    debugp(root_canvas)
    debugp("Creating Shadow layers")
    ui_skeleton = ResourceLoader.load(Global.Root + "shadowpainter_toolpanel.tscn", "", true)

    for level in Global.World.AllLevels:
        create_shadow_level(level)
        var nslayer = TextureRect.new()
        var nslayer_tex = Global.World.EmbeddedTextures.get(slayer_id(level))
        nslayer.set_texture(nslayer_tex)
        nslayer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        nslayer.material.blend_mode = CanvasItem.BLEND_MODE_DISABLED
        VisualServer.canvas_item_set_clip(nslayer.get_canvas_item(), false)
        shadow_layers[slayer_id(level)] = nslayer
        
    debupg("Setting up brushes")
    for brush in self._brushes.values():
        brush.Global = Global
    
    self._brush_selected = self._brushes.keys()[0]

    debugp("Creating ShadowCanvas")
    control = ShadowCanvasPainter.new()
    control.Global = Global
    control.current_shadow_layer = get_current_slayer()
    control.set_brush(self._brushes[self._brush_selected])
    Global.World.add_child(control)


    self.ui()



# Creates the shadow layer at -50 for given level
func create_shadow_layer(level) -> void:
    debugp("Fetching layers for level {label}".format({
        "label": level.Label
    }))
    # Fetch JSON of layers, can't use .Layers cause it's a SortedDict
    var layers: Dictionary = level.SaveLayers()
    var newlayers: Dictionary = {
        -50: "Shadow Layer"
    }
    debugp("Creating shadow layer -50")
    if layers.get(-50) != null:
        debugp("ShadowLayer already present")
    else:
        layers[-50] = "Shadow Layer"
        debugp("Loading altered layers")
        level.LoadLayers(newlayers)

# Returns the shadow layer ID for the current level
func slayer_id(level) -> String:
    return "{levelID}-S_LAYER".format({"levelID": level.ID})

func get_current_slayer() -> TextureRect:
    var cur_level = Global.World.GetLevelByID(Global.World.CurrentLevelId)
    return self.shadow_layers.get(slayer_id(cur_level))


### Tool Functions ###

func ui() -> void:
    debugp("Init SPT")
    debugp(self.ui_skeleton)
    self._tool_panel = Global.Editor.Toolset.CreateModTool(
        self,
        "Effects",
        "ShadowPainter",
        "Shadow Painter",
        "res://ui/icons/buttons/color_wheel.png"
    )
    self._tool_panel.UsesObjectLibrary = false
    # self.ui_instance = self.ui_skeleton.instance()
    # self._tool_panel.add_child(self.ui_instance)
    self._tool_panel.print_tree_pretty()

    # self._ui_root = $"VBoxContainer/MarginBox/"
    # self._brushbox = $"BrushBox"
    # self._colorbox = $"ColorBox"
    # self._strength_slider = $"Strength"
    # self._size_slider = $"BrushSize"

    self._tool_panel.BeginNamedSection("SizeBox")
    self._tool_panel.CreateLabel("Brush Size")
    self._tool_panel.CreateSlider("_brush_size", 20.0, 1.0, 400.0, 1.0, false)
    self._tool_panel.EndSection()

    self._tool_panel.CreateLabel("Brush Strength")
    self._tool_panel.CreateSlider("_brush_strength", 75.0, 0.0, 100.0, 1.0, false)

    self._tool_panel.CreateLabel("Brush Color")
    self._colorbox = self._tool_panel.CreateColorPalette("brush_color", false, "#ff0000", ["#ff0000"], false, true)
    self._colorbox.connect("color_changed", self, "on_change_brush_color")

func ChangeColors(colors: Array, name: String) -> void:
    debugp("Colors changed")

func on_change_brush_color(color) -> void:
    debugp("Color Set")
    self._brush_color = color
    self._brushes[self._brush_selected].set_color(color)

    


func on_tool_enable(tool_id) -> void:
    debugp("SPT enabled")
    self._enabled = true

func on_tool_disable(tool_id) -> void:
    debugp("SPT disabled")
    self._enabled = false

func on_content_input(input: InputEvent) -> void:
    if self._enabled:
        self.control._on_tool_input(input)

# Main class that handles actually rendering the brush strokes
class ShadowCanvasPainter extends Control:
    var Global

    var canvas: Viewport
    var current_shadow_layer: TextureRect
    var current_shadow_image: ImageTexture = ImageTexture.new()
    var render_layer: TextureRect
    var canvas_texture: ViewportTexture

    var _prev_mouse_pos
    var _is_painting: bool = false
    var _stroke_finished: bool = false
    var _should_paint = false

    var _pen: Node2D
    var brush: ShadowBrush = ShadowBrush.new()
    var texture_done = false
    const DEBUG = true

    signal stroke_finished(position)
    signal stroke_started(position)

    func debugp(msg):
        if DEBUG:
            printraw("SCP: ")
            print(msg)
        else:
            pass

    func _ready() -> void:
        debugp("Creating painter Viewport")


        self.mouse_filter = Control.MOUSE_FILTER_PASS

        self.size_flags_horizontal = SIZE_EXPAND
        self.size_flags_vertical = SIZE_EXPAND

        self.render_layer = TextureRect.new()
        self.render_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        self.render_layer.material.blend_mode = CanvasItem.BLEND_MODE_DISABLED

        canvas = Viewport.new()

        canvas.size = Global.World.WorldRect.size
        canvas.usage = Viewport.USAGE_2D
        canvas.transparent_bg = true
        canvas.gui_disable_input = true

        # canvas.render_target_clear_mode = Viewport.CLEAR_MODE_ONLY_NEXT_FRAME
        canvas.render_target_v_flip = true
        self.canvas_texture = canvas.get_texture()

        _pen = Node2D.new()
        canvas.add_child(_pen)
        _pen.connect("draw", self, "_on_draw")

        add_child(canvas)

        var rt = canvas.get_texture()
        render_layer.set_texture(rt)
        
        current_shadow_image.create_from_image(canvas_texture.get_data())

        add_child(current_shadow_layer)
        add_child(render_layer)
        


        Global.World.connect("mouse_entered", self, "_on_mouse_entered")

    func _process(delta: float) -> void:
        current_shadow_layer.update()

    func _enter_tree() -> void:
        debugp("SCP entered")

    func _on_mouse_entered() -> void:
        debugp("MOUSE ENTERED")

    func _on_tool_input(event: InputEvent) -> void:
        if event is InputEventMouseButton:
            if event.button_index == BUTTON_LEFT and event.pressed:
                self._should_paint = true
                self._pen.update()
            elif event.button_index == BUTTON_LEFT and !event.pressed:
                self._should_paint = false
                self._prev_mouse_pos = null
                self._pen.update()
            else:
                self._should_paint = false
                self._prev_mouse_pos = null
                self._pen.update()
        if self._should_paint:
            self._pen.update()

    func set_brush(nbrush: ShadowBrush) -> void:
        nbrush.set_size(self.brush.brush_radius)
        nbrush.set_color(self.brush.color)
        self.brush = nbrush

    func _on_draw() -> void:
        var mouse_pos = get_local_mouse_position()
        # Brush selected, and we've been told to paint
        if self.brush != null and self._should_paint:
            # If this is the first call, reset mouse pos to ensure separation of strokes
            if !self._is_painting:
                debugp("Stroke Started")
                self.emit_signal("stroke_started", mouse_pos)
                self._prev_mouse_pos = mouse_pos
            self._is_painting = true
            self.brush.paint(_pen, mouse_pos, self._prev_mouse_pos)
        # Otherwise, we shouldn't be painting
        else:
            # If we were painting, we need to finish our stroke
            if self._is_painting:
                debugp("Stroke Finished")
                self.emit_signal("stroke_finished", mouse_pos)
                self._on_stroke_finish()
                self._stroke_finished = true
                self._is_painting = false
        
        self._prev_mouse_pos = mouse_pos
    
    func _on_stroke_finish() -> void:
        var timer = OS.get_ticks_msec()
        var viewport_render: Image = self.canvas_texture.get_data()
        debugp("Retrieved viewport render took " + str(OS.get_ticks_msec() - timer))
        timer = OS.get_ticks_msec()
        var main_render: Image = self.current_shadow_image.get_data()
        debugp("Retrieved existing render took " + str(OS.get_ticks_msec() - timer))
        timer = OS.get_ticks_msec()
        var viewport_updated_region: Rect2 = viewport_render.get_used_rect()
        main_render.blend_rect(
            viewport_render, 
            viewport_updated_region, 
            viewport_updated_region.position
        )
        debugp("Completed blending took " + str(OS.get_ticks_msec() - timer))
        debugp("Image Size: {x}, {y}".format({
            "x": main_render.get_width(),
            "y": main_render.get_height()
        }))
        self.current_shadow_image.set_data(main_render)
        self.current_shadow_layer.texture = self.current_shadow_image
        self.brush.on_stroke_end()




class ShadowBrush extends Object:
    var Global

    var brush_radius = 40
    var color: Color = Color.red
    var brush_icon: Texture
    var brush_name: String

    func debugp(msg):
        if DEBUG:
            printraw("BRS: ")
            print(msg)
        else:
            pass

    func paint(pen: Node2D, mouse_pos: Vector2, prev_mouse_pos: Vector2) -> void:
        print("Raw Brush Called")
    
    func set_size(size: float) -> void:
        print("Raw brush called")

    func set_color(color: Color) -> void:
        self.color = color

    func on_select() -> void:
        Global.WorldUI.CursorMode = 5

    func on_stroke_end() -> void:
        pass


class Pencil extends ShadowBrush:
    var stroke_points = []
    var temp_line = Line2D.new()
    var fuck = false
    func _init() -> void:
        self.brush_icon = load("res://ui/icons/tools/cave_brush.png")
        self.brush_name = "Pencil"
        self.temp_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
        self.temp_line.antialiased = false

        

    func paint(pen: Node2D, mouse_pos: Vector2, prev_mouse_pos: Vector2) -> void:
        if !fuck:
            pen.add_child(temp_line)
            self.fuck = true
        if mouse_pos == prev_mouse_pos and len(temp_line.points) == 0:
            temp_line.add_point(mouse_pos)
        else:
            temp_line.add_point(mouse_pos)
            # # pen.draw_circle(mouse_pos, self.brush_radius, self.color)
            # pen.draw_line(prev_mouse_pos, mouse_pos, self.color, self.brush_radius * 2)
            # # pen.draw_circle(prev_mouse_pos, self.brush_radius, self.color)
    
    func set_size(size: float) -> void:
        if size < 1:
            debugp("Ignoring attempt to set size to less than 1")
            return
        
        self.brush_radius = size
        self.temp_line.width = size * 2
        Global.WorldUI.CursorRadius = self.brush_radius

    func set_color(color) -> void:
        self.color = color
        self.temp_line.default_color = color

    func on_stroke_end() -> void:
        self.temp_line.clear_points()

    func on_select() -> void:
        debugp("Set Cursor")
        Global.WorldUI.CursorMode = 5

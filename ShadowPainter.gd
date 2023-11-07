class_name ShadowPainter
var script_class = "tool"

var shadow_layers: Dictionary = {}
var shadow_control
var root_canvas: CanvasLayer
var control: ShadowCanvasPainter

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

    for level in Global.World.AllLevels:
        create_shadow_level(level)
        var nslayer = TextureRect.new()
        var nslayer_tex = Global.World.EmbeddedTextures.get(slayer_id(level))
        # nslayer.expand = true
        # nslayer.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
        nslayer.set_texture(nslayer_tex)
        nslayer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        VisualServer.canvas_item_set_clip(nslayer.get_canvas_item(), false)
        shadow_layers[slayer_id(level)] = nslayer

    debugp("Creating ShadowCanvas")
    control = ShadowCanvasPainter.new()
    control.Global = Global
    control.current_shadow_layer = get_current_slayer()
    Global.World.add_child(control)


# func update(delta):
#     debugp(control.get_size())


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

func slayer_id(level) -> String:
    return "{levelID}-S_LAYER".format({"levelID": level.ID})

func get_current_slayer() -> TextureRect:
    var cur_level = Global.World.GetLevelByID(Global.World.CurrentLevelId)
    return self.shadow_layers.get(slayer_id(cur_level))



class ShadowCanvasPainter extends Control:
    var Global
    var canvas: Viewport
    var current_shadow_layer: TextureRect
    var _pen: Node2D
    const DEBUG = true

    func debugp(msg):
        if DEBUG:
            printraw("SCP: ")
            print(msg)
        else:
            pass

    func _ready() -> void:
        debugp("Creating painter Viewport")

        self.mouse_filter = Control.MOUSE_FILTER_IGNORE

        canvas = Viewport.new()

        canvas.size = Global.World.WorldRect.size
        canvas.usage = Viewport.USAGE_2D
        canvas.transparent_bg = true
        canvas.gui_disable_input = true

        canvas.render_target_clear_mode = Viewport.CLEAR_MODE_ONLY_NEXT_FRAME
        canvas.render_target_v_flip = true

        _pen = Node2D.new()
        canvas.add_child(_pen)
        _pen.connect("draw", self, "_on_draw")

        add_child(canvas)

        var rt = canvas.get_texture()
        current_shadow_layer.set_texture(rt)
        debugp(current_shadow_layer)

        add_child(current_shadow_layer)

    func _process(delta: float) -> void:
        _pen.update()
        current_shadow_layer.update()

    func _enter_tree() -> void:
        debugp("SCP entered")

    # func _process(delta: float) -> void:
    #     if self.current_shadow_layer.visible: debugp("VISIBLE")
    #     else: debugp("NOT VISIBLE")

    func _on_draw() -> void:
        var mouse_pos = get_local_mouse_position()
        _pen.draw_rect(Rect2(
            Vector2(0, 0),
            Vector2(8960, 10240)
        ), Color.blue, false)
        if Input.is_mouse_button_pressed(BUTTON_LEFT):
            _pen.draw_circle(mouse_pos, 200, Color.red)
    
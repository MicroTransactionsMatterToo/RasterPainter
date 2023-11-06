## Copyright MBMM 2023
class_name ShadowPainter 
var script_class = "tool"
var slayers: Dictionary
var World = load("res://scripts/world/World.cs")
var WorldUI = load("res://scripts/world/WorldUI.cs")
var brush = ShadowBrush.new()
const DEBUG = true
var lpl = 0

func debugp(msg):
    if DEBUG:
        printraw("SPD: ")
        print(msg)
    else:
        pass

func update(delta):
    brush.update(delta)

func on_content_input(event: InputEvent) -> void:
    debugp("HOUWHE")
    brush.on_content_input(event)

func start() -> void:
    debugp("ShadowPainter loaded")
    debugp("Creating Shadow Levels")

    # Create shadow layers on load
    for level in Global.World.AllLevels:
        create_shadow_level(level)
        var nslayer = init_slayer(level)
        slayers[slayer_id(level)] = nslayer
    brush = ShadowBrush.new()
    debugp("BRUSH")
    print(typeof(brush))
    brush.Global = Global
    brush.ui()
    brush.shadowpainter_root = self

func create_shadow_level(level) -> void:
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

func get_current_slayer() -> ShadowLayer:
    var cur_level = Global.World.GetLevelByID(Global.World.CurrentLevelId)
    return self.slayers.get(slayer_id(cur_level))

func init_slayer(level) -> ShadowLayer:
    debugp("Creating ShadowLayer instance for level {level}".format({"level": level.Label}))
    var slayer
    # Check for existing shadow layer texture
    if Global.World.EmbeddedTextures.get(slayer_id(level)) != null:
        debugp("Found existing shadow texture")
        var slayer_texture = Global.World.EmbeddedTextures.get(slayer_id(level))
        debugp(str(ShadowLayer))
        slayer = ShadowLayer.new()
        slayer.Global = Global
        slayer.texture = slayer_texture
        level.add_child(slayer)
        debugp("Added layer")
    else:
        debugp("No existing shadow texture found")
        print(ShadowLayer)
        slayer = ShadowLayer.new()
        slayer.Global = Global
        slayer.brush = brush
        print(slayer)
        level.add_child(slayer)
        debugp("Added layer")
    return slayer

class ShadowBrush extends Object:
    var brushImage: Image = load("res://textures/brushes/soft_circle.png").duplicate(false) as Image
    var radius: float
    var size: float = 30000.0
    var painting = false
    var enabled = false
    var shadowpainter_root: ShadowPainter
    var Global

    func debugp(msg):
        if DEBUG:
            printraw("SBD: ")
            print(msg)
        else:
            pass
    
    func ui() -> void:
        debugp("Initialising UI")
        var tool_panel = Global.Editor.Toolset.CreateModTool(self, "Objects", "ShadowPaint", "Shadow Painter", "res://ui/icons/buttons/color_wheel.png")
    
        tool_panel.UsesObjectLibrary = false

    func on_tool_enable(tool_id) -> void:
        debugp("Shadow Paint tool selected")
        self.enabled = true
        Global.WorldUI.CursorMode = 5
        Global.WorldUI.CursorRadius = self.get_world_radius()
    
    func on_tool_disable(tool_id) -> void:
        debugp("Shadow Paint tool deselected")
        self.enabled = false
        Global.WorldUI.CursorMode = 0

    func on_content_input(event: InputEvent) -> void:
        if event is InputEventMouseButton:
            if event.button_index == BUTTON_LEFT and event.pressed:
                self.painting = true

            if event.button_index == BUTTON_LEFT and not event.pressed:
                self.painting = false
                var slayer = shadowpainter_root.get_current_slayer()
                slayer.update_texture()

    func update(delta):
        if self.enabled and self.painting:
            # debugp("UPDATED: {a}, {b}".format({
            #     "a": str(self.enabled),
            #     "b": str(self.painting)
            # }))
            var slayer = shadowpainter_root.get_current_slayer()
            var mouse_pos = Global.WorldUI.MousePosition
            slayer.update()
            var offset = Vector2(
                -Global.WorldUI.CursorRadius - 32.0,
                -Global.WorldUI.CursorRadius - 32.0
            )
            debugp("Drawing circle at {x}, {y}", {
                "x": mouse_pos.x,
                "y": mouse_pos.y
            })



    func update_brush():
        var lsize = int(self.size)
        self.brushImage = load("res://textures/brushes/soft_circle.png").duplicate(false) as Image
        self.brushImage.resize(lsize * 4, lsize * 4, Image.INTERPOLATE_BILINEAR)
        Global.WorldUI.CursorRadius = self.get_world_radius()
    
    func get_world_radius() -> float:
        return self.size * 2.0 * 0.75
    

# Actual Shadow layer, handles rendering and whatnot. 
#
# Ideally would be in it's own file, but 
# importing scripts is a bit of a mess at the moment
class ShadowLayer extends MeshInstance2D:
    var shadow_texture: ImageTexture
    var shadow_splat: Image
    var shadow_image: Image
    var shadow_image2: Image
    var shadow_res_factor = 0.75
    var height: int
    var width: int
    var brush: ShadowBrush
    var shader
    var Global

    func debugp(msg):
        if DEBUG:
            printraw("SDL: ")
            print(msg)
        else:
            pass

    func _enter_tree() -> void:
        debugp("ShadowLayer for level {levelName} entered tree".format({
            "levelName": get_parent().Label
        }))
        var woxels = Global.World.WoxelDimensions
        self.width = round(woxels.x * self.shadow_res_factor)
        self.height = round(woxels.y * self.shadow_res_factor)

        self.shader = load(Global.Root + "ShadowLayer.shader")
        self.material = self.material.duplicate(false) as ShaderMaterial
        self.material.shader = self.shader

        create_embedded_texture()
        create_surface()

        self.shader.set_shader_param("TEXTURE", self.shadow_texture)

    func _exit_tree() -> void:
        debugp("ShadowLayer for level {levelName} exited tree".format({
            "levelName": get_parent().Label
        }))
    

    func _draw() -> void:
        debugp("DRAW")
        if brush.painting and brush.enabled:
            self.mesh.draw_circle(
                Global.WorldUI.MousePosition,
                300.0,
                Color.green
            )
    
    func world_to_texture(pos: Vector2) -> Vector2:
        return pos * self.shadow_res_factor + Vector2(0.5, 0.5)
    
    func create_surface() -> void:
        var surfaceTool = SurfaceTool.new()
        var woxels = Global.World.WoxelDimensions
        surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
        surfaceTool.add_vertex(Vector3(0, 0, 0))
        surfaceTool.add_vertex(Vector3(0, woxels.y, 0))
        surfaceTool.add_vertex(Vector3(woxels.x, 0, 0))
        surfaceTool.add_vertex(Vector3(woxels.x, woxels.y, 0))
        self.mesh = surfaceTool.commit(null, 2194432)

    func paint(brush) -> void:
        self.brush = brush
        # var t = self.world_to_texture(offset + position)
        # debugp("Painting at {x}, {y} ({xa}, {ya})".format({
        #     "x": position.x,
        #     "y": position.y,
        #     "xa": t.x,
        #     "ya": t.y
        # }))
        # self.shadow_image.blend_rect(
        #     brush,
        #     Rect2(
        #         Vector2(0, 0),
        #         brush.get_size()
        #     ),
        #     position
        # )
        # # self.shadow_image.blend_towards_channel(
        # #     brush, 
        # #     t,
        # #     3, 
        # #     rate
        # # )

    func create_embedded_texture() -> void:
        debugp("Creating texture with dimensions {x}, {y}".format({
            "x": self.width,
            "y": self.height
        }))
        self.shadow_image = Image.new()
        self.shadow_image.create(
            self.width,
            self.height,
            false,
            Image.FORMAT_RGBA8
        )
        self.shadow_image.fill(Color(0, 0, 0, 0))
        self.shadow_image.lock()
        self.shadow_texture = ImageTexture.new()
        self.shadow_texture.create_from_image(self.shadow_image, 4)
        self.texture = self.shadow_texture

        self.shadow_splat = Image.new()
        self.shadow_splat.create(
            self.width,
            self.height,
            false,
            Image.FORMAT_RGBA8
        )
        self.shadow_splat.fill(Color.green)
    
    func update_texture() -> void:
        debugp("Updating Shadow texture")
        self.shadow_image.lock()
        self.shadow_texture.create_from_image(self.shadow_image, 4)
        self.texture = self.shadow_texture
        self.shader.set_shader_param("TEXTURE", self.shadow_texture)
        debugp(self.shadow_image.get_pixel(20, 20))
class_name ShadowPainter
var script_class = "tool"

var BrushManagerC
var BrushManager
var ShadowLayerC
var ShadowLayer
var ShadowControlC
var ShadowControl
var LayerManagerC
var LayerManager

var _enabled = false
var _tool_panel

var _size_slider
var _strength_slider
var _colorbox
var _brushbox

var layers: Array = []
var layer_num: int = -50

var brush_manager
var layer_manager
var control


const LOG_LEVEL = 4

func logv(msg):
	if LOG_LEVEL > 3:
		printraw("[V] SP: ")
		print(msg)
	else:
		pass

func logi(msg):
	if LOG_LEVEL >= 1:
		printraw("[I] SP: ")
		print(msg)
	else:
		pass

# ModScript funcs

func start() -> void:
	logi("ShadowPainter loaded")
	# This is required due to a bug when accessing subclasses. None of this 
	# would be necessary if Dungeondraft didn't append shit to mod scripts
	# that means you can't extend anything without using a subclass
	BrushManagerC 	= ResourceLoader.load(Global.Root + "BrushManagerC.gd", "GDScript", true)
	BrushManager 	= load(Global.Root + "BrushManagerC.gd").BrushManager
	ShadowLayerC 	= ResourceLoader.load(Global.Root + "ShadowLayerC.gd", "GDScript", true)
	ShadowLayer 	= load(Global.Root + "ShadowLayerC.gd").ShadowLayer
	ShadowControlC 	= ResourceLoader.load(Global.Root + "ShadowControlC.gd", "GDScript", true)
	ShadowControl 	= load(Global.Root + "ShadowControlC.gd").ShadowControl
	LayerManagerC 	= ResourceLoader.load(Global.Root + "LayerManagerC.gd", "GDScript", true)
	LayerManager	= load(Global.Root + "LayerManagerC.gd").LayerManager


	self.name = "ShadowPainter"

	self.ui()
	
	self.layer_manager = LayerManager.new(Global)
	
	self.brush_manager = BrushManager.new(self._tool_panel)
	self.brush_manager.Global = Global
	
	self.control = ShadowControl.new(Global, self.brush_manager, self.layer_manager)
	# self.layer_manager.get_level_ids()

	logv("Managers Created")
	logv(Global.World.EmbeddedTextures)
	logv(ResourceLoader.get_recognized_extensions_for_type("Shader"))
	logv("FUCK")
	logv(ResourceFormatLoader.get_resource_type(Global.Root + "ShadowLayer.shader"))

	
	self.control.add_child(self.brush_manager)
	Global.World.add_child(self.control)
	
	self.brush_manager.set_toolpanel(self._tool_panel)
	logv("Finished start-up")


func on_tool_enable(tool_id) -> void:
	logv("Tool Enabled")
	self._enabled = true

func on_tool_disable(tool_id) -> void:
	logv("Tool Disabled")
	self._enabled = false

func on_level_change() -> void:
	pass
	# logv("Level Changed, from {old} to {new}".format({
	# 	"old": self._prev_frame_level.ID,
	# 	"new": Global.World.Level.ID
	# }))
	# var level_layers = self.get_current_level_layers()
	# logv("New level layers: " + str(level_layers))

	# if len(level_layers) == 1:
	# 	logv("Only one layer exists on new level, setting it as current layer")
	# 	self.layer_num = level_layers[0].layer_num
	# if len(level_layers) == 0:
	# 	logv("No layers on new level, setting layer_num to default (-50)")
	# 	self.layer_num = -50
	
	# self.control.current_layer = self.get_current_layer()
	# self.control.set_level(Global.World.Level.ID, level_layers)
	

func on_content_input(input):
	if self._enabled:
		self.control._on_tool_input(input)

func _on_change_brush_color(color) -> void:
	# print(Global.World.EmbeddedTextures.keys())
	# print(World.EmbeddedTextures.values())
	self.brush_manager.color = color
	# self.control._viewport_mod.modulate.a = color.a
	# self.control._pen.self_modulate.a = color.a

func _on_change_brush_size(nsize) -> void:
	self.brush_manager.size = nsize



#### UI ####

func ui() -> void:
	logv("Set up UI")
	self._tool_panel = Global.Editor.Toolset.CreateModTool(
		self,
		"Effects",
		"ShadowPainter",
		"Shadow Painter",
		"res://ui/icons/buttons/color_wheel.png"
	)
	self._tool_panel.UsesObjectLibrary = false
	var toolpanel_scene = ResourceLoader.load(Global.Root + "ui/toolpanel.tscn")
	var ColorPalette = load("res://scripts/ui/elements/ColorPalette.cs")
	var _toolpanel_inst = toolpanel_scene.instance()


	self._tool_panel.add_child(_toolpanel_inst)
	logv(self._tool_panel.get_path())

	var col_pal = ColorPalette.new(false)
	var cols = [Color.red.to_html(), Color.green.to_html()]
	col_pal.name = "BrushPalette"

	self._tool_panel.get_node("PanelRoot/BrushControls/BrushSettings/BColorC").add_child(col_pal)
	col_pal.AddPresets(cols)

	# self._tool_panel.BeginNamedSection("SizeBox")
	# self._tool_panel.CreateLabel("Brush Size")
	# self._size_slider = self._tool_panel.CreateSlider("_brush_size", 20.0, 1.0, 400.0, 1.0, false)
	# self._size_slider.connect("value_changed", self, "_on_change_brush_size")
	# self._tool_panel.EndSection()

	# self._tool_panel.CreateLabel("Brush Strength")
	# self._tool_panel.CreateSlider("_brush_strength", 75.0, 0.0, 100.0, 1.0, false)


	# self._tool_panel.CreateLabel("Brush Color")
	# self._colorbox = self._tool_panel.CreateColorPalette("brush_color", false, "#ff0000", ["#ff0000"], false, true)
	# self._colorbox.connect("color_changed", self, "_on_change_brush_color")
	

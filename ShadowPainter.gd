class_name ShadowPainter
var script_class = "tool"

# +++++ External Classes +++++
var BrushManagerC
var BrushManager

var LayerManagerC
var LayerManager

var ShadowControlC
var ShadowControl

var PreferencesC
var Preferences

# +++++ State +++++
var _enabled = false

var brush_manager
var layer_manager
var control
var toolpanel
var prefs

# ===== LOGGING =====
const LOG_LEVEL = 4

func logv(msg):
	if LOG_LEVEL > 3:
		printraw("(%d) [V] <ShadowPainter>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass

func logd(msg):
	if LOG_LEVEL > 2:
		printraw("(%d) [D] <ShadowPainter>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass

func logi(msg):
	if LOG_LEVEL >= 1:
		printraw("(%d) [I] <ShadowPainter>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass

# ===== MODSCRIPT ======
func start() -> void:
	logi("ShadowPainter loaded")

	# Class loading
	BrushManagerC 	= ResourceLoader.load(Global.Root + "BrushManagerC.gd", "GDScript", true)
	BrushManager 	= load(Global.Root + "BrushManagerC.gd").BrushManager

	ShadowControlC 	= ResourceLoader.load(Global.Root + "ShadowControlC.gd", "GDScript", true)
	ShadowControl 	= load(Global.Root + "ShadowControlC.gd").ShadowControl

	LayerManagerC 	= ResourceLoader.load(Global.Root + "LayerManagerC.gd", "GDScript", true)
	LayerManager	= load(Global.Root + "LayerManagerC.gd").LayerManager

	PreferencesC 	= ResourceLoader.load(Global.Root + "PreferencesC.gd", "GDScript", true)
	Preferences	= load(Global.Root + "PreferencesC.gd").Preferences

	# Setup
	self.name = "ShadowPainter"
	self.prefs = Preferences.new(Global)
	self.layer_manager = LayerManager.new(Global)
	self.brush_manager = BrushManager.new(Global)


	self.toolpanel = Global.Editor.Toolset.CreateModTool(
		self,
		"Effects",
		"ShadowPainter",
		"Shadow Painter",
		"res://ui/icons/buttons/color_wheel.png"
	)

	self.control = ShadowControl.new(
		Global, 
		self.layer_manager,
		self.brush_manager,
		self.toolpanel,
		self.prefs
	)

	Global.World.add_child(self.control)
	self.toolpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.toolpanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Global.World.has_method("set_meta")
	

	# ===== _Lib =====
	if not Engine.has_signal("_lib_register_mod"):
		logi("_Lib not installed")
	else:
		Engine.emit_signal("_lib_register_mod", self)
		
		var test = self.prefs
		test.hide()
		self.Global.API.ModConfigApi._mod_config_api._mod_menu.add_child(test)
		self.Global.API.ModConfigApi._mod_config_api._mod_config_panels["MBMM.shadow_painter"] = test
		self.Global.API.ModConfigApi._mod_config_api._mod_config_buttons["MBMM.shadow_painter"].connect(
			"pressed", 
			self.Global.API.ModConfigApi._mod_config_api,
			"_config_button_pressed",
			["MBMM.shadow_painter"]
		)
		self.Global.API.ModConfigApi._mod_config_api._mod_config_buttons["MBMM.shadow_painter"].disabled = false
		self.Global.API.ModConfigApi._mod_config_api._preferences_window_api.connect(
			"apply_pressed",
			test,
			"_save_config"
		)

func on_tool_enable(tool_id) -> void:
	logv("ShadowPainter enabled")
	self._enabled = true
	self.control.layerui.visible = true
	# self.brush_manager.size = self.prefs.get_c_val("def_brush_size")
	Global.World.UI.CursorMode = 5

func on_tool_disable(tool_id) -> void:
	logv("ShadowPainter disabled")
	self._enabled = false
	self.control.layerui.visible = false
	Global.World.UI.CursorMode = 1

func on_content_input(input):
	if self._enabled: self.control._on_tool_input(input)



class_name RasterPainter
var script_class = "tool"

# +++++ External Classes +++++
var BrushManagerC
var BrushManager

var LayerManagerC
var LayerManager

var RasterControlC
var RasterControl

var PreferencesC
var Preferences



var skig

# +++++ State +++++
var _enabled = false

var brush_manager
var layer_manager
var control
var toolpanel
var prefs

var _lib_present = false

# ===== LOGGING =====
const LOG_LEVEL = 4

func logv(msg):
	if LOG_LEVEL > 3:
		printraw("(%d) [V] <RasterPainter>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass

func logd(msg):
	if LOG_LEVEL > 2:
		printraw("(%d) [D] <RasterPainter>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass

func logi(msg):
	if LOG_LEVEL >= 1:
		printraw("(%d) [I] <RasterPainter>: " % OS.get_ticks_msec())
		print(msg)
	else:
		pass

# ===== MODSCRIPT ======
func start() -> void:
	logi("RasterPainter loaded")

	# ===== _Lib =====
	if not Engine.has_signal("_lib_register_mod"):
		logi("_Lib not installed")
	else:
		Engine.emit_signal("_lib_register_mod", self)

	# Class loading
	BrushManagerC 	= ResourceLoader.load(Global.Root + "BrushManagerC.gd", "GDScript", true)
	BrushManager 	= load(Global.Root + "BrushManagerC.gd").BrushManager

	RasterControlC 	= ResourceLoader.load(Global.Root + "RasterControlC.gd", "GDScript", true)
	RasterControl 	= load(Global.Root + "RasterControlC.gd").RasterControl

	LayerManagerC 	= ResourceLoader.load(Global.Root + "LayerManagerC.gd", "GDScript", true)
	LayerManager	= load(Global.Root + "LayerManagerC.gd").LayerManager

	PreferencesC 	= ResourceLoader.load(Global.Root + "PreferencesC.gd", "GDScript", true)
	Preferences	= load(Global.Root + "PreferencesC.gd").Preferences



	# Setup
	self.name = "RasterPainter"
	self.prefs = Preferences.new(Global)
	self.layer_manager = LayerManager.new(Global)
	self.brush_manager = BrushManager.new(Global)


	self.toolpanel = Global.Editor.Toolset.CreateModTool(
		self,
		"Effects",
		"RasterPainter",
		"Raster Painter",
		"res://ui/icons/buttons/color_wheel.png"
	)

	self.control = RasterControl.new(
		Global, 
		self.layer_manager,
		self.brush_manager,
		self.toolpanel,
		self.prefs
	)

	

	Global.World.add_child(self.control)
	self.toolpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.toolpanel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	Global.World.set_meta("GlobalSingleton", Global.World.get_node("/root/Global"))
	Global.World.set_meta("RasterControl", self.control)
	Global.World.set_meta("painter_script", Script)

	if Global.API != null:
		self.prefs.hide()
		self.Global.API.ModConfigApi._mod_config_api._mod_menu.add_child(self.prefs)
		self.Global.API.ModConfigApi._mod_config_api._mod_config_panels["MBMM.raster_painter"] = self.prefs
		self.Global.API.ModConfigApi._mod_config_api._mod_config_buttons["MBMM.raster_painter"].connect(
			"pressed", 
			self.Global.API.ModConfigApi._mod_config_api,
			"_config_button_pressed",
			["MBMM.raster_painter"]
		)
		self.Global.API.ModConfigApi._mod_config_api._mod_config_buttons["MBMM.raster_painter"].disabled = false
		self.Global.API.ModConfigApi._mod_config_api._preferences_window_api.connect(
			"apply_pressed",
			self.prefs,
			"_save_config"
		)

	else:
		if not self.prefs.get_c_val("disable_lib_warning"):
			Global.Editor.Warn(
				"_Lib not installed", 
				"""_Lib was not detected as installed. 
				If you do have it installed, make sure it is enabled.
				Undo, Redo and the preferences menu will be unavailable
				This warning will not be shown again!
				"""
			)
			self.prefs.config_dict["disable_lib_warning"] = true
			self.prefs._save_config(true)


func on_tool_enable(tool_id) -> void:
	logv("RasterPainter enabled")
	self._enabled = true
	self.control.layerui.visible = true
	Global.World.UI.CursorMode = 5
	Global.World.UI.UseHalfSnap = true
	Global.World.UI.CursorRadius = self.control.brushmgr.size
	self.control.toolpanelui.on_tool_enable()

func on_tool_disable(tool_id) -> void:
	logv("RasterPainter disabled")
	self._enabled = false
	self.control.layerui.visible = false
	Global.World.UI.CursorMode = 1
	

func on_content_input(input):
	if self._enabled: self.control._on_tool_input(input)



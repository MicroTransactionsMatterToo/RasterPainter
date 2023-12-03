class_name ShadowPainter
var script_class = "tool"

# +++++ External Classes +++++
var BrushManagerC
var BrushManager

var LayerManagerC
var LayerManager

var ShadowControlC
var ShadowControl

# +++++ State +++++
var _enabled = false

var brush_manager
var layer_manager
var control
var toolpanel

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

	# Setup
	self.name = "ShadowPainter"
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
		self.toolpanel
	)

	Global.World.add_child(self.control)
	self.toolpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.toolpanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	logv("Control added as child")

func on_tool_enable(tool_id) -> void:
	logv("ShadowPainter enabled")
	self._enabled = true
	self.control.layerui.visible = true

func on_tool_disable(tool_id) -> void:
	logv("ShadowPainter disabled")
	self._enabled = false
	self.control.layerui.visible = false

func on_content_input(input):
	if self._enabled: self.control._on_tool_input(input)
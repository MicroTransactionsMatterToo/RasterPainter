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
var PainterUIC
var LayerPanel

var _enabled = false
var _tool_panel
var _tool_sidepanel
var _tool_tree

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
	PainterUIC 		= ResourceLoader.load(Global.Root + "PainterUIC.gd", "GDScript", true)
	LayerPanel		= load(Global.Root + "PainterUIC.gd").LayerPanel




	self.name = "ShadowPainter"

	
	self.layer_manager = LayerManager.new(Global)

	self.ui()
	
	self.brush_manager = BrushManager.new(self._tool_panel)
	self.brush_manager.Global = Global
	logv("Managers Created")
	logv(Global.Editor.ObjectLibraryPanel)
	
	self.control = ShadowControl.new(Global, self.brush_manager, self.layer_manager)
	
	self.control.add_child(self.brush_manager)
	Global.World.add_child(self.control)
	
	self.brush_manager.set_toolpanel(self._tool_panel)
	logv("Finished start-up")

	self.layer_panel()
	self.control.emit_signal("level_changed", self.control._current_level)

	


func on_tool_enable(tool_id) -> void:
	logv("Tool Enabled")
	self._enabled = true

func on_tool_disable(tool_id) -> void:
	logv("Tool Disabled")
	self._enabled = false
	

func on_content_input(input):
	if self._enabled:
		self.control._on_tool_input(input)

func _on_change_brush_color(color) -> void:
	self.brush_manager.color = color

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

func layer_panel() -> void:
	var layerpanel_parent = Global.Editor.ObjectLibraryPanel.get_parent()
	var layerpanel = LayerPanel.new(Global, self.layer_manager, self.control)

	layerpanel_parent.add_child(layerpanel)

	# var layerpanel = ResourceLoader.load(Global.Root + "ui/layerpanel.tscn", "", true)
	# var layerpanel_mat = ResourceLoader.load("res://materials/MenuBackground.material", "ShaderMaterial", false)

	# self._tool_sidepanel = layerpanel.instance()
	# self._tool_sidepanel.material = layerpanel_mat
	
	# layerpanel_parent.add_child_below_node(Global.Editor.ObjectLibraryPanel, self._tool_sidepanel)

	# ## Layer Tree Stuff
	# self._tool_tree = self._tool_sidepanel.find_node("ShadowLayers")

func _on_change_level(curr_layer):
	pass

# func populate_tree(curr_layer):
# 	# Clear current entries in layer menu
# 	for item in self._tool_tree.get_children():
# 		self._tool_tree.remove_child(item)
# 		item.queue_free()
	
# 	# Create new entries
# 	var new_layers = self.layer_manager.loaded_layers
# 	new_layers.sort_custom(self.layer_manager, "sort_layers_asc")

# 	for layer in self.layer_manager.loaded_layers:
# 		if layer.level_id == curr_layer.level_id:
# 			var n_item = self.setup_tree_item(layer)
# 			if n_item != null:
# 				self._tool_tree.add_child(n_item)

# func setup_tree_item(layer):
# 	logv("Creating tree entry for " + str(layer))

# 	var tree_item = LayerTreeEntryPrefab.instance()
# 	tree_item.get_node("LayerPreview").texture = layer.world_tex
# 	tree_item.get_node("SelectButton").icon = load("res://ui/icons/misc/approve.png")
# 	tree_item.get_node("DeleteButton").icon = load("res://ui/icons/misc/delete.png")
# 	tree_item.get_node("LayerName").text = str(layer.z_index)

# 	tree_item.get_node("LayerCtrl/MoveUp").icon = load("res://ui/icons/misc/up.png")
# 	tree_item.get_node("LayerCtrl/MoveUp").size = Vector2(25, 25)
# 	tree_item.get_node("LayerCtrl/MoveDown").icon = load("res://ui/icons/misc/down.png")
# 	tree_item.get_node("LayerCtrl/MoveDown").size = Vector2(25, 25)


# 	return tree_item
class_name LayerUIC
var script_class = "tool"


const LOG_LEVEL = 4

const LOCKED_LAYERS = {
        800: "Roofs",
        600: "Walls",
        500: "Portals",
        0: "Water",
        -200: "Floor",
        -300: "Caves",
        -500: "Terrain",
    }

const DIR_UP = true
const DIR_DOWN = false


class Utils extends Object:
    # Loads a `PackedScene`, adds it to the provided object as a child, the removes the 
    # scenes root node
    static func load_scene_inplace(obj, scene_file: String):
        obj.template = ResourceLoader.load(Global.Root + scene_file, "", true)
        var instance = obj.template.instance()
        obj.add_child(instance)
        instance.remove_and_skip()


class LayerPanel extends PanelContainer:
    var Global
    var template

    # Actual tree
    var layer_tree
    # ShadowControl instance
    var scontrol
    # LayerManager instance
    var layerm

    var layer_add_dialog: WindowDialog

    signal layer_order_changed()

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("[V] <LayerUI>: ")
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("[D] <LayerUI>: ")
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("[I] <LayerUI>: ")
            print(msg)
        else:
            pass

    # ===== BUILTINS =====
    func _init(global, layerm, scontrol).() -> void:
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol
        
        Utils.load_scene_inplace(self, "ui/layerpanel.tscn")

        # self.layer_add_dialog = NewLayerDialog.new()
        self.name = "LayerPanel"

    func _ready():
        var panel_mat = ResourceLoader.load("res://materials/MenuBackground.material")

        # TODO: Double check this doesn't need jank
        self.material = panel_mat

        #self.layer_tree = LayerTree.new(Global, self.layerm, self.scontrol)
        $"Margins/Align/LayerTree".replace_by(self.layer_tree)

        self.rect_min_size.x = 256
        self.rect_position = Vector2(651, 0)

        self.size_flags_horizontal = SIZE_FILL
        self.size_flags_vertical = SIZE_FILL

        Global.Editor.get_child("Windows").add_child(self.layer_add_dialog)

        $"Margins/Align/LayerControls/AddLayer".connect(
            "pressed",
            self,
            "show_layer_dialog"
        )
        $"Margins/Align/LayerControls/MoveLayerDown".connect(
            "pressed",
            self,
            "move_layers_down"
        )
        $"Margins/Align/LayerControls/MoveLayerUp".connect(
            "pressed",
            self,
            "move_layers_up"
        )

        self._set_icons()

    func _exit_tree():
        # We should only be exiting the tree if the map is being unloaded
        self.queue_free()
    
    # ===== PRIVATE =====

    func _set_icons():
        $"Margins/Align/LayerControls/MoveLayerUp".icon = load("res://ui/icons/misc/up.png")
        $"Margins/Align/LayerControls/MoveLayerDown".icon = load("res://ui/icons/misc/down.png")
        $"Margins/Align/LayerControls/AddLayer".icon = load("res://ui/icons/buttons/add.png")
        $"Margins/Align/LayerControls/DeleteLayer".icon = load("res://ui/icons/misc/delete.png")

    # ===== MISC UI =====
    func show_layer_dialog():
        self.layer_add_dialog.popup_centered()

    # ===== LAYER MOVEMENT =====
    func move_layers(direction: bool):
        var selected_items = self.layer_tree.current_selection
        if direction == DIR_DOWN:
            selected_items.invert()

        if len(selected_items) == 0: logd("No layers selected, ignoring move request")
        
        for item in selected_items:
            self.move_layer(item, direction)

        self.emit_signal("layer_order_changed")
        
    func move_layer(item: Node2D, direction: bool = DIR_DOWN):
        var item_index = item.get_index()
        var item_next = self.layer_tree.tree.get_child(item_index)
        item_next = item_next - 1 if direction else item_next + 1

        # Handle item above being a layer separator
        if item_next.magic != null:
            var min_new_z = int(item_next.layer_z) - 1
            var valid_groups = self.layer_tree.separators.keys()
            valid_groups.sort()

            var new_z = self.layer_tree.get_group_for_z(min_new_z, direction).layer_z
            var group_zs = self.dialog.get_group_z_array(new_z)

            new_z = group_zs.max() + 1 if group_zs.size() != 0 else new_z + 1
            if group_zs.max() == min_new_z:
                logv("Refusing to move layer to group that is full")
                return
            
            item.layer.set_z_index(new_z)
        
        else:
            var new_z = item_next.layer.z_index
            item_next.layer.set_z_index(item.layer.z_index)
            item.layer.set_z_index(new_z)

class LayerTree extends Panel:
    var Global
    var template

    var layerm
    var scontrol

    var separators := {}
    
    var current_selection setget , get_current_selection
    var tree setget , get_layer_tree

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("[V] <LayerTree>: ")
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("[D] <LayerTree>: ")
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("[I] <LayerTree>: ")
            print(msg)
        else:
            pass

    # ===== BUILTINS =====
    func _init(global, layerm, scontrol).():
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol

        Utils.load_scene_inplace(self, Global.Root + "ui/layertree.tscn")

        self.size_flags_vertical = SIZE_EXPAND_FILL

    func _ready():
        # Remove placeholder
        self.tree.remove_child($"ShadowLayers/ShadowLayer")

        self.scontrol.connect("level_changed", self, "populate_tree", [self.scontrol.curr_level_id])
        self.layerm.connect("layer_added", self, "populate_tree", [self.scontrol.curr_level_id])
        self.layerm.connect("layer_modified", self, "on_layer_modified")

        # Populate group separators
        for key in LOCKED_LAYERS.keys():
            var separator = LayerTreeSep.new(
                [key, LOCKED_LAYERS[key]],
                Global,
                self.layerm,
                self.scontrol
            )
            self.tree.add_child(separator)
            self.separators[key] = separator

    # ===== TREE FUNCTIONS =====
    func get_group_for_z(z_index: int, direction: bool = DIR_UP):
        logv("Get group for %d" % z_index)
        var group
        var locked_keys = LOCKED_LAYERS.keys()
        locked_keys.sort()

        var insert_index = locked_keys.bsearch(z_index)
        locked_keys.insert(insert_index, z_index)

        if direction == DIR_UP:
            group = locked_keys[insert_index + 1]
        else:
            group = locked_keys[insert_index - 1]

        return self.separators[group] if group != null else null

    func get_layer_items(show_hidden = false) -> Array:
        var rval := []

        for item in self.tree.get_children():
            if show_hidden and item.magic == null:
                rval.append(item)
            elif not item.visible and item.magic == null:
                rval.append(item)
        
        return rval
    
    func create_item(layer):
        logd("Creating TreeItem for %s" % layer)
        var new_item = LayerTreeItem.new(Global, self)
        new_item.layer = layer
        self.tree.add_child(new_item)

    # ===== UI =====

    ### populate_tree
    # Completely wipes and then repopulates the tree
    # Called when:
    # - Current Level Changes
    # - Layer is added
    func populate_tree(level_id):
        logv("Populating layer tree")
        var level_layers = self.layerm.get_layers_in_level(level_id)
        level_layers.sort_custom(self.layerm, "sort_layers_desc")

        var tree_items = self.get_layer_items(true)

        # Hide all entries and set layer to null
        for entry in tree_items:
            entry.visible = false
            entry.layer = null

        # Assign layers to tree items as we go, creating new tree items if needed
        for idx in range(level_layers.size()):
            var layer = level_layers[idx]
            var tree_item = tree_items[idx]

            if tree_item == null: self.create_item(layer)
            else:
                logv("Reusing existing TreeItem for %s" % layer)
                tree_item.layer = layer
                tree_item.visible = true
                tree_item.selected = false
        
        self.order_tree()

    ### `order_tree`
    # Moves TreeItems around into their correct order
    # Called when:
    # - `populate_tree` is called
    # - A layer within the current level is modified
    func order_tree():
        # Repeat the ordering process twice. It's not clear why this is required
        for __ in range(2):
            var entries = self.get_layer_items()
            entries.sort_custom(self, "sort_entries_asc")

            for entry in entries:
                var group = self.get_group_for_z(entry.layer.z_index)
                if group != null:
                    self.tree.move_child(entry, group.get_index() + 1)
                else:
                    self.tree.move_child(entry, 0)

    
    # ===== GETTERS =====

    # ---- self.tree get
    func get_layer_tree() -> CanvasItem:
        return $"ShadowLayers" as CanvasItem

    # ---- self.current_selection get
    func get_current_selection() -> Array:
        var selected = []
        for entry in self.get_layer_items():
            if entry.selected:
                selected.append(entry)
        
        return selected

    # ===== SIGNAL HANDLERS =====
    func on_layer_modified(layer):
        if layer.level_id == self.scontrol.curr_level_id:
            self.order_tree()

    # ===== SORTING =====
    func sort_entries_asc(a, b):
        if null in [a.layer.z_index, b.layer.z_index]:
            return false
        
        if a.layer.z_index < b.layer.z_index:
            return true
        return false

class LayerTreeItem extends PanelContainer:
    var Global
    var template

    var layer setget set_layer, get_layer
    var _layer

    var selected setget set_selected, get_selected
    var _selected := false

    var active: bool setget , get_active

    var tree

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("[V] <LayerTreeItem>: ")
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("[D] <LayerTreeItem>: ")
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("[I] <LayerTreeItem>: ")
            print(msg)
        else:
            pass

    # ===== BUILTINS =====
    func _init(global, tree).() -> void:
        self.Global = global
        self.tree = tree

        Utils.load_scene_inplace(self, Global.Root + "ui/layertree_item.tscn")
        
        self.self_modulate = Color(0, 0, 0, 0)
        self.rect_min_size.x = 50

        self.mouse_filter = MOUSE_FILTER_PASS

        var preview_stylebox = ResourceLoader.load(
            Global.Root + "ui/styleboxes/layertreeitem.stylebox", 
            "", 
            true
        )
        $"HB/Preview".add_stylebox_override('panel', preview_stylebox)

        # Load chequered background for preview
        var background_texture := ImageTexture.new()
        background_texture.load(Global.Root + "icons/preview_background.png")
        $"HB/Preview/PreviewBackground".texture = background_texture

        self._set_visibility_button_textures()

        $"LayerButton".connect("toggled", self, "on_toggle")
        $"HB/Visibility".connect("toggled", self, "on_visibility_toggle")

    # ===== UI =====
    func _set_visibility_button_textures():
        var vis_button: CheckButton = $"HB/Visibility"
        
        var checked_tex = ImageTexture.new()
        checked_tex.load(Global.Root + "icons/visible.png")
        checked_tex.set_size_override(Vector2(15, 15))
        vis_button.set("custom_icons/checked", checked_tex)

        var unchecked_tex = ImageTexture.new()
        unchecked_tex.load(Global.Root + "icons/hidden.png")
        unchecked_tex.set_size_override(Vector2(15, 15))
        vis_button.set("custom_icons/unchecked", unchecked_tex)

        vis_button.rect_scale = Vector2(0.75, 0.75)

    # ===== GETTERS/SETTERS ======

    # ---- self.active get/set
    func get_active() -> bool:
        if self.tree == null: return false
        return len(tree.current_selection) == 1 and self._selected

    # ---- self.layer get/set
    func get_layer(): return self._layer

    func set_layer(new_layer) -> void:
        self._layer = new_layer

        $"HB/Preview/LayerPreview".texture = self._layer.texture
        $"HB/LayerName".text = self._layer.layer_name
        $"HB/ZLevel".text = self._layer.z_index

    # ---- self.selected get/set
    func get_selected() -> bool: return self._selected
    
    func set_selected(val: bool) -> void:
        self._selected = val
        $"LayerButton".set_pressed_no_signal(val)


class LayerTreeSep extends HBoxContainer:
    var Global
    var template

    var layerm
    var scontrol

    var magic = "LTSP"

    var layer_z setget , get_layer_z

    func _init(layer_info, global, layerm, scontrol).():
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol

        Utils.load_scene_inplace(self, Global.Root + "ui/layertree_group_sep.tscn")

        self.set_anchor_and_margin(0, 0, 0, false)
        self.size_flags_horizontal = SIZE_EXPAND_FILL
        self.size_flags_vertical = SIZE_SHRINK_CENTER

        $"HB/LockedLayerIndex".text = layer_info[0]
        $"HB/LockedLayerName".text = layer_info[1]

    func get_layer_z() -> int:
        return int($"HB/LockedLayerIndex".text)

    func _to_string() -> String:
        return "[LayerTreeSep <Name: {n}, Z-Level: {z}]".format({
            "n": $"HB/LockedLayerName".text,
            "z": self.layer_z
        })

class NewLayerDialog extends WindowDialog:
    var Global
    var template

    var layerm
    var scontrol

    var dropdown: OptionButton

    var ShadowLayerC
    var ShadowLayer

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("[V] <NewLayerDialog>: ")
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("[D] <NewLayerDialog>: ")
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("[I] <NewLayerDialog>: ")
            print(msg)
        else:
            pass
    
    # ===== BUILTIN =====
    func _init(global, layerm, scontrol).():
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol


        ShadowLayerC 	= ResourceLoader.load(Global.Root + "ShadowLayerC.gd", "GDScript", true)
        ShadowLayer 	= load(Global.Root + "ShadowLayerC.gd").ShadowLayer

        self.window_title = "Create New Layer"
        self.name = "NewLayerDialog"

        Utils.load_scene_inplace(self, Global.Root + "ui/create_layer_dialog.tscn")

        self.set_anchor(0, 0.5, false, false)
        self.rect_position = Vector2(135, -10)
        self.rect_size = Vector2(300, 150)

        self.popup_exclusive = true
        self.size_flags_horizontal = SIZE_FILL
        self.size_flags_vertical = SIZE_FILL

        $"Margins/Align/AcceptButton".connect(
            "pressed",
            self,
            "create_layer"
        )
        self.dropdown = $"Margins/Align/LayerNum/LayerNumEdit"

        for z_index in LOCKED_LAYERS.keys():
            dropdown.add_item(LOCKED_LAYERS[z_index], z_index)

    func create_layer():
        var new_layer_index: int
        var layer_group_z = dropdown.get_selected_id()

        var filtered_zs = self.get_group_z_array(layer_group_z)

        if len(filtered_zs) == 0:
            new_layer_index = layer_group_z + 1
            logv("No existing layers in group, creating at group Z + 1")
        else:
            new_layer_index = filtered_zs.max() + 1
            logv("Existing layers in group, creating at Z: %d" % (filtered_zs.max() + 1))
        
        var layer_name = $"Margins/Align/LayerName/LayerNameEdit".text

        var new_layer = ShadowLayer.new()
        new_layer.create_new(self.scontrol.curr_level_id, new_layer_index, layer_name)
        self.layerm.add_layer(new_layer)

        self.scontrol.set_active_layer(new_layer)

    func get_group_z_array(layer_group_z):
        var locked_zs = LOCKED_LAYERS.keys()
        locked_zs.sort()

        var layer_group_index = locked_zs.find(layer_group_z)
        var next_group_z = locked_zs[layer_group_index + 1]
        next_group_z = next_group_z if next_group_z != null else 8192

        var current_zs = self.layerm.layer_z_indexes(self.scontrol.curr_level_id)
        var filtered_zs = []
        for z in current_zs:
            if z > (next_group_z - 1) or z < layer_group_z or z == -50:
                continue
            else:
                filtered_zs.append(z)
        
        return filtered_zs
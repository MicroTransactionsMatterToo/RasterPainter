class_name PainterUIC
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


class LayerPanel extends PanelContainer:
    var Global
    var template

    

    var layerm
    var layer_tree
    var control

    var dialog

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("[V] LUI: ")
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("[I] LUI: ")
            print(msg)
        else:
            pass

    func _init(global, layer_mgr, control).() -> void:
        logv("LayerPanel init")
        self.Global = global
        self.template = ResourceLoader.load(Global.Root + "ui/layerpanel.tscn", "", true)
        self.layerm = layer_mgr
        self.control = control

        self.dialog = NewLayerDialog.new(Global, self.layerm, self.control)

        self.name = "LayerPanel"

    func _ready() -> void:
        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()

        
        var panel_mat = ResourceLoader.load("res://materials/MenuBackground.material", "ShaderMaterial", false)
        
        self.material = ShaderMaterial.new()
        self.material = panel_mat
    

        self.layer_tree = LayerTree.new(Global, self.layerm, self.control)
        $"Margins/Align/LayerTree".replace_by(layer_tree)

        self.rect_min_size.x = 256
        self.rect_position = Vector2(651, 0)

        self.size_flags_horizontal = SIZE_FILL
        self.size_flags_vertical = SIZE_FILL
        self.visible = true

        Global.Editor.get_child("Windows").add_child(self.dialog)

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
            "move_layer_up"
        )

        self._set_icons()

    func _set_icons():
        $"Margins/Align/LayerControls/MoveLayerUp".icon = load("res://ui/icons/misc/up.png")
        $"Margins/Align/LayerControls/MoveLayerDown".icon = load("res://ui/icons/misc/down.png")
        $"Margins/Align/LayerControls/AddLayer".icon = load("res://ui/icons/buttons/add.png")
        $"Margins/Align/LayerControls/DeleteLayer".icon = load("res://ui/icons/misc/delete.png")
    
    func _exit_tree() -> void:
        self.queue_free()

    
    func show_layer_dialog():
        self.dialog.popup_centered()
    
    func test():
        print(self.layer_tree.current_selection)

    func move_layers_down():
        var selected = self.layer_tree.current_selection

        if len(selected) == 0:
            logv("No layers, ignoring move request")
            return

        var entry_index = selected[0].get_index()
        var next_item = self.layer_tree.tree.get_child(entry_index + 1)

        # Handle next item being layer separator
        if next_item.magic != null:
            var new_group_z = int(next_item.layer_num)
            var valid_groups = self.layer_tree.separators.keys()
            valid_groups.sort()

            new_group_z -= 1   
            var actual_z = self.layer_tree.get_group_below(new_group_z).layer_num
            logv("Next item is layer sep {sep_idx}, special handling".format({
                "sep_idx": new_group_z
            }))

            var existing_group_zs = self.dialog.get_group_z_array(actual_z)
            var new_layer_z = existing_group_zs.max() + 1 if existing_group_zs.size() != 0 else actual_z + 1
            if existing_group_zs.max() == new_group_z:
                logv("Refusing to move layer in group that is full")
                return
            
            selected[0].layer.set_layer_num(new_layer_z)
        
        # Call twice to fix oddities with sorting. I'll fix this some other time
        self.layer_tree._on_layer_change(selected[0])
        selected[0].selected = true

    func move_layer_up():
        var selected = self.layer_tree.current_selection

        if len(selected) == 0:
            logv("No layers, ignoring move request")
            return

        var entry_index = selected[0].get_index()
        var next_item = self.layer_tree.tree.get_child(entry_index - 1)

        # Handle next item being layer separator
        if next_item.magic != null:
            var new_group_z = int(next_item.layer_num)
            var valid_groups = self.layer_tree.separators.keys()
            valid_groups.sort()

            new_group_z -= 1   
            var actual_z = self.layer_tree.get_group_for_index(new_group_z).layer_num
            logv("Next item is layer sep {sep_idx}, special handling".format({
                "sep_idx": new_group_z
            }))

            var existing_group_zs = self.dialog.get_group_z_array(actual_z)
            var new_layer_z = existing_group_zs.max() + 1 if existing_group_zs.size() != 0 else actual_z + 1
            if existing_group_zs.max() == new_group_z:
                logv("Refusing to move layer in group that is full")
                return
            
            print("BEGIN ----------------------")
            print(Global.World.EmbeddedTextures)
            print(self.layerm.loaded_layers)
            selected[0].layer.set_layer_num(new_layer_z)
            print(Global.World.EmbeddedTextures.keys())
            print(self.layerm.loaded_layers)
            print("END ------------------------")
        
        # Call twice to fix oddities with sorting. I'll fix this some other time

        self.layer_tree._on_layer_change(selected[0])
        selected[0].selected = true

        
        print(Global.World.EmbeddedTextures)

        

class LayerTree extends Panel:
    var Global
    var template

    var layerm
    var control

    var separators = {}

    var current_selection setget , _get_current_selection
    var tree setget , _get_tree
    

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("[V] LUI: ")
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("[I] LUI: ")
            print(msg)
        else:
            pass

    func _init(global, layer_mgr, control).() -> void:
        logv("LayerTree init")

        self.Global = global
        self.name = "LayerTree"
        self.template = ResourceLoader.load(Global.Root + "ui/layertree.tscn", "", true)
        self.layerm = layer_mgr
        self.control = control

        self.size_flags_vertical = SIZE_EXPAND_FILL
        self.tree = $"ShadowLayers"

    func _ready() -> void:
        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()

        $"ShadowLayers".remove_child($"ShadowLayers/ShadowLayer")

        self.control.connect("level_changed", self, "_on_level_change")
        self.layerm.connect("layer_created", self, "_on_layer_change")

        for key in LOCKED_LAYERS.keys():
            var sep = LayerTreeSep.new(
                [key, LOCKED_LAYERS[key]],
                Global,
                self.layerm,
                self.control
            )
            $"ShadowLayers".add_child(sep)
            self.separators[key] = sep

    func _on_level_change(nlevel_id):
        logv("On Level Change")
        var new_level_layers: Array = self.layerm.load_level_layers(nlevel_id)
        print(new_level_layers)
        new_level_layers.sort_custom(self.layerm, "sort_layers_desc")

        var tree_items = self.get_items(true)
        logv(tree_items)


        # Hide all existing entries
        for entry in tree_items:
            entry.visible = false
            entry.layer = null

        # Assign layers to tree items as we go, creating tree items if needed
        for idx in range(new_level_layers.size()):
            var layer = new_level_layers[idx]
            var tree_item = tree_items[idx]

            if tree_item == null:
                logv("Creating new entry for " + str(layer))
                var new_tree_item = LayerTreeItem.new(Global)
                new_tree_item.layer = layer
                $"ShadowLayers".add_child(new_tree_item)
            else:
                logv("Reusing existing entry for " + str(layer))
                tree_item.layer = layer
                tree_item.visible = true
                tree_item.focused = false
                tree_item.selected = false
        
        # Order layers, and place them in the right groups
        var entries = self.get_items()
        entries.sort_custom(self, "sort_entries_asc")

        for entry in entries:
            var group = self.get_group_for_index(entry.layer.layer_num)
            if group != null:
                $"ShadowLayers".move_child(entry, group.get_index() + 1)
            else:
                $"ShadowLayers".move_child(entry, 0)

        entries = self.get_items()
        entries.sort_custom(self, "sort_entries_asc")

        for entry in entries:
            var group = self.get_group_for_index(entry.layer.layer_num)
            if group != null:
                $"ShadowLayers".move_child(entry, group.get_index() + 1)
            else:
                $"ShadowLayers".move_child(entry, 0)
    
    func _on_layer_change(nlayer):
        self._on_level_change(self.control._current_level)

    # Get the group (Dungeondraft Locked Layer Z-level) for a given Z-index
    # Returns null if the index is above Roofs (Z: 800)
    func get_group_for_index(z_index):
        logv("GGFI for " + str(z_index))
        var locked_zs = LOCKED_LAYERS.keys()
        locked_zs.sort()

        var insert_index = locked_zs.bsearch(z_index)
        locked_zs.insert(insert_index, z_index)

        var group_above = locked_zs[insert_index + 1]

        logv("GA was " + str(group_above))

        if group_above != null:
            return self.separators[group_above]
        else:
            return null

    func get_group_below(z_index):
        var locked_zs = LOCKED_LAYERS.keys()
        locked_zs.sort()

        var insert_index = locked_zs.bsearch(z_index)
        locked_zs.insert(insert_index, z_index)

        var group_above = locked_zs[insert_index - 1]

        if group_above != null:
            return self.separators[group_above]
        else:
            return null

    # Returns a list of all LayerTreeItem's
    func get_items(show_hidden = false) -> Array:
        var rval = []

        # Fetch all current tree items
        for item in $"ShadowLayers".get_children():
            if show_hidden:
                if item.magic == null:
                    rval.append(item)
            elif item.visible == (!show_hidden) and item.magic == null:
                rval.append(item)
        
        return rval


    func sort_entries_asc(a, b):
        if null in [a.layer.layer_num, b.layer.layer_num]:
            return false
        
        if a.layer.layer_num < b.layer.layer_num:
            return true
        return false
    

    
    func _get_current_selection():
        var selection = []
        for entry in self.get_items():
            if entry.selected:
                selection.append(entry)

        return selection
    
    func _get_tree():
        return $"ShadowLayers"


class LayerTreeItem extends PanelContainer:
    var Global
    var template
    var layer setget _set_layer, _get_layer
    var _layer

    var selected setget set_selected, get_selected
    var _selected = false

    var focused setget set_focused, get_focused
    var _focused = false

    signal layer_num_changed(layer, from, to)

    func _init(global).() -> void:
        self.Global = global
        self.template = ResourceLoader.load(Global.Root + "ui/layertree_item.tscn", "", true)

        self.self_modulate = Color(0, 0, 0, 0)
        self.rect_min_size.x = 50

        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()

        var preview_stylebox = ResourceLoader.load(Global.Root + "ui/styleboxes/layertreeitem.stylebox", "", true)
        $"HB/Preview".add_stylebox_override('panel', preview_stylebox)

        # Load chequered background
        var background_text = ImageTexture.new()
        background_text.load(Global.Root + "icons/preview_background.png")
        $"HB/Preview/PreviewBackground".texture = background_text

        var vis_b: CheckButton = $"HB/Visibility"
        var checked_tex = ImageTexture.new()
        checked_tex.load(Global.Root + "icons/visible.png")
        checked_tex.set_size_override(Vector2(15, 15))
        vis_b.set("custom_icons/checked", checked_tex)
        
        var unchecked_tex = ImageTexture.new()
        unchecked_tex.load(Global.Root + "icons/hidden.png")
        unchecked_tex.set_size_override(Vector2(15, 15))
        vis_b.set("custom_icons/unchecked", unchecked_tex)

        vis_b.rect_scale = Vector2(0.75, 0.75)
        

    func _ready() -> void:
        self.mouse_filter = MOUSE_FILTER_PASS

        $"LayerButton".connect("toggled", self, "on_toggle")
        $"HB/Visibility".connect("toggled", self, "on_visibility_toggle")

        self.focused = false

    func _set_layer(n_layer) -> void:
        self._layer = n_layer
        
        $"HB/Preview/LayerPreview".texture = self._layer.world_tex
        $"HB/LayerName".text = self._layer.layer_name
        $"HB/ZLevel".text = self._layer.z_index

    func _get_layer(): return self._layer
    
    func on_toggle(toggle_val):
        if toggle_val:
            var only_selected = true
            for child in self.get_parent().get_children():
                if child.selected:
                    only_selected = false
            
            self.selected = true
            self.focused = only_selected
        else:
            self.focused = false
            self.selected = false

        var selected_children = []
        for child in self.get_parent().get_children():
            if child.selected:
                selected_children.append(child)
        
        if len(selected_children) > 1:
            for child in selected_children:
                child.focused = false
        elif len(selected_children) == 1:
            selected_children[0].focused = true

    func on_visibility_toggle(toggle_val):
        self.layer.visible = toggle_val
    # --- self.selected get/set

    func get_selected() -> bool:
        return self._selected
    
    func set_selected(val: bool) -> void:
        self._selected = val
        $"LayerButton".set_pressed_no_signal(val)

    # --- self.focused get/set
    
    func get_focused() -> bool:
        return self._focused and self.selected

    func set_focused(val: bool) -> void:
        self._focused = val
        $"HB/Preview".self_modulate = Color(1, 1, 1, 1 if self.focused else 0)

class LayerTreeSep extends HBoxContainer:
    var Global
    var template

    var layerm
    var control

    var magic = "LTSP"

    var layer_num setget , _get_layernum

    func _init(layer_info, global, layerm, control).() -> void:
        self.Global = global
        self.layerm = layerm
        self.control = control

        self.template = ResourceLoader.load(Global.Root + "ui/layertree_group_sep.tscn", "", true)
        var instance = self.template.instance()

        self.add_child(instance)
        instance.remove_and_skip()

        self.set_anchor_and_margin(0, 0, 0, false)

        $"HB/LockedLayerName".text = layer_info[1]
        $"HB/LockedLayerIndex".text = layer_info[0]
    
    func _ready() -> void:
        self.size_flags_horizontal = SIZE_EXPAND_FILL
        self.size_flags_vertical = SIZE_SHRINK_CENTER

    func _get_layernum():
        return int($"HB/LockedLayerIndex".text)

    func _to_string() -> String:
        return "[LayerTreeSep <Name: {n}, Z-Level: {z}]".format({
            "n": $"HB/LockedLayerName".text,
            "z": self.layer_num
        })

class NewLayerDialog extends WindowDialog:
    var Global
    var template
    var layerm
    var control

    var dropdown: OptionButton

    func _init(global, layerm, control).() -> void:
        self.Global = global
        self.layerm = layerm
        self.control = control
        self.window_title = "Create New Layer"
        self.name = "NewLayerDialog"

        self.template = ResourceLoader.load(Global.Root + "ui/create_layer_dialog.tscn", "", true)
        var instance = self.template.instance()
        
        self.add_child(instance)
        instance.remove_and_skip()

        self.set_anchor(0, 0.5, false, false)
        self.rect_position = Vector2(135, -10)
        self.popup_exclusive = true
        self.rect_size = Vector2(300, 150)
        self.size_flags_horizontal = SIZE_FILL
        self.size_flags_vertical = SIZE_FILL

    func _ready() -> void:
        $"Margins/Align/AcceptButton".connect("pressed", self, "create_layer")
        self.dropdown = $"Margins/Align/LayerNum/LayerNumEdit"
        
        for z_index in LOCKED_LAYERS.keys():
            dropdown.add_item(LOCKED_LAYERS[z_index], z_index)

    func create_layer():
        var new_layer_index = null
        var layer_group_z = dropdown.get_selected_id()

        var filtered_zs = self.get_group_z_array(layer_group_z)

        # Handle group with no layers
        if len(filtered_zs) == 0:
            new_layer_index = layer_group_z + 1
            print("No existing layers in group, creating new layer at group Z + 1")
        else:
            new_layer_index = filtered_zs.max() + 1
            print("Existing layers in group, creating layer at Z: " + str(filtered_zs.max() + 1))

        var layer_name = $"Margins/Align/LayerName/LayerNameEdit".text

        var new_layer = self.layerm.create_layer(
            self.control._current_level,
            new_layer_index,
            layer_name
        )
        

        self.control.set_current_layer(new_layer)

    func get_group_z_array(layer_group_z):
        var locked_zs = LOCKED_LAYERS.keys()
        
        print("Creating layer above: " + str(LOCKED_LAYERS[layer_group_z]))
        locked_zs.sort()
        
        # Get permissible Z range for selected group
        var layer_group_idx = locked_zs.find(layer_group_z)
        var next_group_z = locked_zs[layer_group_idx + 1] if locked_zs[layer_group_idx + 1] != null else 8192
        print("Z of group above selected: " + str(next_group_z))

        # Find existing layers in current range
        var current_zs = self.layerm.z_indexes(self.control._current_level)
        var filtered_zs = []
        # Filter current Z indexes to only those in the relevant range
        for item in current_zs:
            if item > (next_group_z - 1) or item < layer_group_z or item == -50:
                pass
            else:
                filtered_zs.append(item)

        return filtered_zs
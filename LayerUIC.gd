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

class LayerPanel extends PanelContainer:
    var Global
    var template

    # Actual tree
    var layer_tree
    # RasterControl instance
    var scontrol
    # LayerManager instance
    var layerm

    var prefs

    var layer_add_dialog
    var import_dialog
    var export_dialog
    var layer_properties_dialog

    var LAYER_DICT setget , get_layer_dict

    signal layer_order_changed()

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <LayerUI>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <LayerUI>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <LayerUI>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    # ===== BUILTINS =====
    func _init(global, layerm, scontrol).() -> void:
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol
        
        self.template = ResourceLoader.load(Global.Root + "ui/layerpanel.tscn", "", true)
        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()

        self.prefs = Global.World.get_meta("painter_config")

        # self.layer_add_dialog = NewLayerDialog.new()
        self.name = "LayerPanel"

    func _process(delta):
        $"Margins/Align/LayerControls/DeleteLayer".disabled = len(self.layer_tree.get_layer_items()) <= 1
    func _ready():
        logv("LayerUI ready")
        var panel_mat = ResourceLoader.load("res://materials/MenuBackground.material")

        # TODO: Double check this doesn't need jank
        self.material = panel_mat

        self.layer_tree = LayerTree.new(Global, self.layerm, self.scontrol)
        logv("layertree %s" % self.layer_tree)
        $"Margins/Align/LayerTree".replace_by(self.layer_tree)

        self.layer_add_dialog = NewLayerDialog.new(Global, self.layerm, self.scontrol, self)
        self.export_dialog = ExportDialog.new(Global, self.layerm, self.scontrol, self)
        self.import_dialog = ImportDialog.new(Global, self.layerm, self.scontrol, self)
        self.layer_properties_dialog = LayerPropertiesDialog.new(Global, self.layerm, self.scontrol, self)

        self.rect_min_size.x = 256
        self.rect_position = Vector2(651, 0)

        self.size_flags_horizontal = SIZE_FILL
        self.size_flags_vertical = SIZE_FILL

        Global.Editor.get_child("Windows").add_child(self.layer_add_dialog)
        Global.Editor.get_child("Windows").add_childw(self.import_dialog)
        Global.Editor.get_child("Windows").add_child(self.export_dialog)
        Global.Editor.get_child("Windows").add_child(self.layer_properties_dialog)

        $"Margins/Align/LayerControls/AddLayer".connect(
            "pressed",
            self,
            "show_layer_dialog"
        )

        $"Margins/Align/LayerControls/DeleteLayer".connect(
            "pressed",
            self,
            "delete_layers"
        )
        $"Margins/Align/LayerControls/MoveLayerDown".connect(
            "pressed",
            self,
            "move_layers",
            [DIR_DOWN]
        )
        $"Margins/Align/LayerControls/MoveLayerUp".connect(
            "pressed",
            self,
            "move_layers",
            [DIR_UP]
        )
        $"Margins/Align/LayerControls/Import".connect(
            "pressed",
            self.import_dialog,
            "popup_centered"
        )

        $"Margins/Align/LayerControls/Export".connect(
            "pressed",
            self.export_dialog,
            "popup_centered"
        )

        $"Margins/Align/LayerControls/LayerProps".connect(
            "pressed",
            self.layer_properties_dialog,
            "popup_centered"
        )

        self._set_icons()

    func _exit_tree():
        # We should only be exiting the tree if the map is being unloaded
        self.queue_free()
    
    # ===== PRIVATE =====
    func get_layer_dict() -> Dictionary:
        if self.prefs == null:
            return LOCKED_LAYERS
        else:
            if self.prefs.get_c_val("use_user_layers"):
                var layers =  Global.World.Level.SaveLayers()
                var keys = layers.keys()
                keys.append_array(LOCKED_LAYERS.keys())
                keys.sort()
                keys.invert()
                var real_layers = {}
                for key in keys:
                    if layers[key] != null:
                        var layer_name = layers[key]
                        if not "Below " in layer_name and not "Above " in layer_name:
                            real_layers[key] = layers[key]
                    else:
                        real_layers[key] = LOCKED_LAYERS[key]

                return real_layers
            else:
                return LOCKED_LAYERS

    func _set_icons():
        $"Margins/Align/LayerControls/MoveLayerUp".icon     = load("res://ui/icons/misc/up.png")
        $"Margins/Align/LayerControls/MoveLayerDown".icon   = load("res://ui/icons/misc/down.png")
        $"Margins/Align/LayerControls/AddLayer".icon        = load("res://ui/icons/buttons/add.png")
        $"Margins/Align/LayerControls/DeleteLayer".icon     = load("res://ui/icons/misc/delete.png")
        $"Margins/Align/LayerControls/Import".icon          = load("res://ui/icons/menu/open.png")
        $"Margins/Align/LayerControls/Export".icon          = load("res://ui/icons/menu/export.png")
        $"Margins/Align/LayerControls/LayerProps".icon      = load("res://ui/icons/misc/level.png")

    # ===== MISC UI =====
    func show_layer_dialog():
        self.layer_add_dialog.popup_centered()

    # ===== LAYER MANAGEMENT =====
    func delete_layers():
        var selected_items = self.layer_tree.current_selection
        logv("deleting %d layers, %s" % [
            selected_items.size(), 
            selected_items
        ])
        var delete_records = []
        for item in selected_items:
            if item.layer != null and is_instance_valid(item.layer):
                delete_records.append(
                    self.scontrol.history_manager.record_layer_delete(
                        item.layer
                    ))
            self.delete_layer(item)
                
        self.layer_tree.get_layer_items()[0].set_selected(true)
        yield(get_tree(), "idle_frame")
        self.layer_tree.populate_tree(self.scontrol.curr_level_id)
        self.scontrol.history_manager.record_bulk_layer_delete(delete_records)
    
    func delete_layer(item: CanvasItem):
        if (item == null or item.layer == null): return
        
        self.scontrol.layerm.remove_layer(item.layer)
        item.layer.delete()
        item.layer = null
        item.visible = false
        item.queue_free()
        


    # ===== LAYER MOVEMENT =====
    func move_layers(direction: bool):
        logd("Moving layers, direction: %s" % direction)
        var selected_items = self.layer_tree.current_selection
        logv("got selection")
        if direction == DIR_DOWN:
            selected_items.invert()
        
        if len(selected_items) == 0:
            logd("No layers selected, ignoring move request")
            return
        
        logd("Moving layers")
        var move_entries = []
        for item in selected_items:
            logv("moving item %s" % item)
            var old_z = item.layer.z_index
            self.move_layer(item, direction)
            var move_entry = [item.layer.uuid, old_z, item.layer.z_index]
            logv("add move_entry: %s" % [move_entry])
            move_entries.append(move_entry)
        
        logv("Moved layers")
        self.scontrol.history_manager.record_layer_move(move_entries)
        self.emit_signal("layer_order_changed")
    
    ## move_layer
    # Handles moving an individual layer in the given direction
    func move_layer(item: CanvasItem, direction: bool = DIR_DOWN):
        logv("move_layer called, item: %s, direction: %s" % [item, direction])
        var item_index = item.get_index()
        item_index = item_index - 1 if direction else item_index + 1
        var item_next = self.layer_tree.tree.get_child(item_index)
        if item_next == null: return

        logv("next item found: %s" % item_next)

        # Handle item above being a layer separator
        if item_next.magic != null:
            logv("next item was separator")
            var min_new_z = int(item_next.layer_z) - 1
            var valid_groups = self.layer_tree.separators.keys()
            valid_groups.sort()

            var new_z = self.layer_tree.get_group_for_z(min_new_z, direction).layer_z
            logv("got new_z: %d" % new_z)
            var group_zs = self.get_group_z_array(new_z)
            logv("got group_zs: %s" % [group_zs])

            new_z = group_zs.max() + 1 if group_zs.size() != 0 else new_z + 1
            if group_zs.max() == min_new_z:
                logv("Item below is in the way")
                if group_zs.size() == len(range(min_new_z, group_zs.max())):
                    logv("Group full")
                

            
            item.layer.set_z_index(new_z)
        
        else:
            if is_instance_valid(item_next.layer):
                var new_z = item_next.layer.z_index
                item_next.layer.set_z_index(item.layer.z_index)
                item_next.update_preview()
                item.layer.set_z_index(new_z)
                item.update_preview()
            else:
                item_next.queue_free()

    ## get_group_z_array
    # Returns array of RasterLayer z-indexes within given layer group
    func get_group_z_array(layer_group_z):
        logv("get_group_z_array for %s" % layer_group_z)
        var locked_zs = self.scontrol.layerui.LAYER_DICT.keys()
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

class LayerTree extends Panel:
    var Global
    var template

    var layerm
    var scontrol

    var separators := {}
    
    var current_selection setget , get_current_selection
    var active_item setget , get_active_item
    var tree setget , get_layer_tree

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <LayerTree>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <LayerTree>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <LayerTree>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    # ===== BUILTINS =====
    func _init(global, layerm, scontrol).():
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol

        self.template = ResourceLoader.load(Global.Root + "ui/layertree.tscn", "", true)
        var instance = template.instance()
        self.add_child(instance)
        instance.remove_and_skip()

        self.size_flags_vertical = SIZE_EXPAND_FILL

    func _ready():
        # Remove placeholder
        self.tree.remove_child($"RasterLayers/RasterLayer")

        self.scontrol.connect("level_changed", self, "populate_tree")
        self.layerm.connect("layer_added", self, "on_layer_added")
        self.layerm.connect("layer_modified", self, "on_layer_modified")

        # Populate group separators
        for key in self.scontrol.layerui.LAYER_DICT.keys():
            var separator = LayerTreeSep.new(
                [key, self.scontrol.layerui.LAYER_DICT[key]],
                Global,
                self.layerm,
                self.scontrol
            )
            self.tree.add_child(separator)
            self.separators[key] = separator

        self.populate_tree(self.scontrol.curr_level_id)

    # ===== TREE FUNCTIONS =====
    func get_group_for_z(z_index: int, direction: bool = DIR_UP):
        logv("Get group for %d" % z_index)
        var group
        var locked_keys = self.scontrol.layerui.LAYER_DICT.keys()
        locked_keys.sort()

        logv("keys sorted")

        var insert_index = locked_keys.bsearch(z_index)
        locked_keys.insert(insert_index, z_index)
        logv('key inserted')

        if direction == DIR_UP:
            group = locked_keys[insert_index + 1]
        else:
            group = locked_keys[insert_index - 1]

        logv("group set, result was %s (%s)" % [group, self.separators[group]])
        return self.separators[group] if group != null else null

    func get_layer_items(show_hidden = false, include_separators = false) -> Array:
        var rval := []

        for item in self.tree.get_children():
            if show_hidden and item.magic == null:
                rval.append(item)
            if include_separators and item.magic == "LTSP":
                rval.append(item)
            elif item.visible == (!show_hidden) and item.magic == null:
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

        logv("sorted level_layers: %s" % [level_layers])

        var tree_items = self.get_layer_items(true)
        logv('got tree_items: %s' % [tree_items])

        # Hide all entries and set layer to null
        for entry in tree_items:
            logv("hiding %s" % entry)
            entry.visible = false
            entry.layer = null

        logv("hid tree_items")

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
        return $"RasterLayers" as CanvasItem

    # ---- self.current_selection get
    func get_current_selection() -> Array:
        var selected = []
        for entry in self.get_layer_items():
            if entry.selected:
                selected.append(entry)
        return selected

    # ---- self.active_item get
    func get_active_item():
        for entry in self.get_layer_items():
            if entry.active:
                return entry

    # ===== SIGNAL HANDLERS =====
    func on_layer_modified(layer):
        if layer.level_id == self.scontrol.curr_level_id:
            self.order_tree()

    func on_layer_added(layer):
        logv("layer added")
        self.populate_tree(self.scontrol.curr_level_id)

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
            printraw("(%d) [V] <LayerTreeItem>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <LayerTreeItem>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <LayerTreeItem>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    # ===== BUILTINS =====
    func _init(global, tree).() -> void:
        self.Global = global
        self.tree = tree

        self.template = ResourceLoader.load(Global.Root + "ui/layertree_item.tscn", "", true)
        var instance = template.instance()
        self.add_child(instance)
        instance.remove_and_skip()
        
        self.rect_min_size.x = 50
        
        self.mouse_filter = MOUSE_FILTER_PASS
        
        var preview_stylebox = ResourceLoader.load(
            Global.Root + "ui/styleboxes/layertreeitem.stylebox", 
            "", 
            true
        )
        $"HB/Preview".add_stylebox_override('panel', preview_stylebox)
        self.self_modulate = Color(0, 0, 0, 0)

        # Load chequered background for preview
        var background_texture := ImageTexture.new()
        background_texture.load(Global.Root + "icons/preview_background.png")
        $"HB/Preview/PreviewBackground".texture = background_texture

        self._set_visibility_button_textures()

        $"LayerButton".connect("toggled", self, "on_toggle")
        $"HB/Visibility".connect("toggled", self, "on_visibility_toggle")

    func _process(delta):
        $"HB/Preview".self_modulate = Color(1, 1, 1, (1 if self.active else 0))
        if (
            self.tree.scontrol.active_layer != self._layer and 
            self.active and
            self._layer != null
        ):
            self.tree.scontrol.set_active_layer(self._layer)

    # ===== UI =====
    func update_preview():
        if self._layer != null and is_instance_valid(self._layer):
            $"HB/Preview/LayerPreview".texture = self._layer.texture

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

    # ===== SIGNAL HANDLERS =====
    func on_toggle(val):
        if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CONTROL):
            self._selected = !self._selected
        else:
            var toggle_val = val if self.tree.current_selection.size() == 1 else true
            for item in self.tree.get_layer_items():
                item.selected = false

            self.selected = toggle_val

    func on_visibility_toggle(val):
        if self._layer != null:
            self._layer.visible = val
            self._layer.set_meta("visibility", val)

    func on_layer_modified(layer):
        if layer == null or self._layer == null: return
        $"HB/Preview/LayerPreview".texture = self.tree.scontrol.result_texture
        $"HB/LayerName".text = self._layer.layer_name
        $"HB/ZLevel".text = self._layer.z_index

    # ===== GETTERS/SETTERS ======

    # ---- self.active get/set
    func get_active() -> bool:
        if self.tree == null: return false
        if self.tree.scontrol.active_layer.uuid == self._layer.uuid:
            return true
        return len(tree.current_selection) == 1 and self._selected

    # ---- self.layer get/set
    func get_layer(): return self._layer

    func set_layer(new_layer) -> void:
        if new_layer == null:
            if self._layer != null:
                self._layer.disconnect("layer_modified", self, "on_layer_modified")
            self._layer = null
        else:
            if self._layer != null:
                self._layer.disconnect("layer_modified", self, "on_layer_modified")

            self._layer = new_layer
            self._layer.connect("layer_modified", self, "on_layer_modified")
            ($"HB/Visibility" as Button).set_pressed_no_signal(self._layer.visible)

            $"HB/Preview/LayerPreview".texture = self._layer.texture
            $"HB/LayerName".text = self._layer.layer_name
            $"HB/ZLevel".text = self._layer.z_index

    # ---- self.selected get/set
    func get_selected() -> bool: 
        return self._selected
    
    func set_selected(val: bool) -> void:
        self._selected = val
        $"LayerButton".set_pressed_no_signal(val)


class LayerTreeSep extends HBoxContainer:
    var Global
    var template

    var layerm
    var scontrol
    var sep_name setget , _get_sep_name

    var magic = "LTSP"

    var layer_z setget , get_layer_z

    func _init(layer_info, global, layerm, scontrol).():
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol

        self.template = ResourceLoader.load(Global.Root + "ui/layertree_group_sep.tscn", "", true)
        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()

        self.set_anchor_and_margin(0, 0, 0, false)
        self.size_flags_horizontal = SIZE_EXPAND_FILL
        self.size_flags_vertical = SIZE_SHRINK_CENTER

        $"HB/LockedLayerIndex".text = layer_info[0]
        $"HB/LockedLayerName".text = layer_info[1]

    func get_layer_z() -> int:
        return int($"HB/LockedLayerIndex".text)

    func _get_sep_name():
        return $"HB/LockedLayerName".text
        
    func _to_string() -> String:
        return "[LayerTreeSep <Name: {n}, Z-Level: {z}]".format({
            "n": $"HB/LockedLayerName".text,
            "z": self.layer_z
        })

class NewLayerDialog extends AcceptDialog:
    var Global
    var template
    
    var tree
    var layerm
    var scontrol

    var dropdown: OptionButton

    var RasterLayerC
    var RasterLayer

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <NewLayerDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <NewLayerDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <NewLayerDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    # ===== BUILTIN =====
    func _init(global, layerm, scontrol, tree).():
        logv("init")
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol
        self.tree = tree


        # Load classes
        RasterLayerC =	ResourceLoader.load(Global.Root + "RasterLayerC.gd", "GDScript", true)
        RasterLayer = 	load(Global.Root + "RasterLayerC.gd").RasterLayer

        self.window_title = "Create New Layer"
        self.name = "NewLayerDialog"

        self.template = ResourceLoader.load(Global.Root + "ui/create_layer_dialog.tscn", "", true)
        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()

        self.set_anchor(0, 0.5, false, false)
        self.rect_position = Vector2(135, -10)
        self.rect_size = Vector2(300, 150)

        self.popup_exclusive = false
        self.size_flags_horizontal = SIZE_FILL
        self.size_flags_vertical = SIZE_FILL

        self.connect("confirmed", self, "create_layer")
        self.dropdown = $"Margins/Align/LayerNum/LayerNumEdit"

        for z_index in self.scontrol.layerui.LAYER_DICT.keys():
            self.dropdown.add_item(self.scontrol.layerui.LAYER_DICT[z_index], z_index)

    ## create_layer
    # Instantiates a RasterLayer, adds it to the layer manager, then updates the UI
    func create_layer():
        logv("UI create new layer called")
        var new_layer_index: int
        var layer_group_z = self.dropdown.get_selected_id()
        
        logv("layer_group_z is %s" % layer_group_z)

        var filtered_zs = self.tree.get_group_z_array(layer_group_z)

        logv("zs in group: %s" % [filtered_zs])

        if len(filtered_zs) == 0:
            new_layer_index = layer_group_z + 1
            logv("No existing layers in group, creating at group Z + 1")
        else:
            new_layer_index = filtered_zs.max() + 1
            logv("Existing layers in group, creating at Z: %d" % (filtered_zs.max() + 1))
        
        var layer_name = $"Margins/Align/LayerName/LayerNameEdit".text
        layer_name = layer_name if layer_name != "" else "New Layer"
        logv("layer_name is %s" % layer_name)
        logv(RasterLayer)
        var new_layer = RasterLayer.new(Global)
        logv("new_layer: %s" % new_layer)
        new_layer.create_new(self.scontrol.curr_level_id, new_layer_index, layer_name)
        logv("new_layer initialized: %s" % new_layer)
        self.layerm.add_layer(new_layer)
        self.scontrol.history_manager.record_layer_add(
            new_layer, 
            {
                "level_id": self.scontrol.curr_level_id,
                "z_index": new_layer_index,
                "name": layer_name
            }
        )

        self.scontrol.set_active_layer(new_layer)
        self.tree.layer_tree.populate_tree(self.scontrol.curr_level_id)

class ImportDialog extends ConfirmationDialog:
    var Global
    var template

    var tree
    var layerm
    var scontrol
    var prefs

    var align
    
    var insert_layer: OptionButton
    var layer_name: LineEdit
    var size_mode: OptionButton
    var file_lineedit: LineEdit
    var browse_button: Button
    var premult: CheckBox

    var import_file_path setget set_file_path, get_file_path
    var _import_file_path

    var image_filter setget , _get_image_filter

    var RasterLayerC
    var RasterLayer

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <ImportDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <ImportDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <ImportDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    # ===== BUILTINS =====
    func _init(global, layerm, scontrol, tree).():
        logv("init")
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol
        self.tree = tree
        self.prefs = Global.World.get_meta("painter_config")

        RasterLayerC    = ResourceLoader.load(Global.Root + "RasterLayerC.gd", "GDScript", true)
        RasterLayer     = load(Global.Root + "RasterLayerC.gd").RasterLayer


        self.window_title = "Import Layer"
        self.name = "ImportDialog"

        self.template = ResourceLoader.load(Global.Root + "ui/import_dialog.tscn", "", true)
        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()
        logv("load template %s %s" % [instance, self])

        
        self.resizable = true
        self.rect_size = Vector2(500, 200)
        
        self.align = $"Align"
        self.insert_layer = $"Align/LayerNum/LayerNumEdit"
        self.layer_name = $"Align/LayerName/LayerNameEdit"
        self.size_mode = $"Align/SizeSettings/OptionButton"
        self.premult = $"Align/PremultAlpha/CheckBox"
        
        self.file_lineedit = $"Align/HBoxContainer/FilePathC/FilePath"
        self.browse_button = $"Align/HBoxContainer/FilePathC/Browse"
    
        
        for z_index in self.scontrol.layerui.LAYER_DICT.keys():
            self.insert_layer.add_item(self.scontrol.layerui.LAYER_DICT[z_index], z_index)

        self.connect("about_to_show", self, "_on_about_to_show")
        
        self._setup_connections()

    func _setup_connections():
        self.browse_button.connect(
            "pressed",
            self,
            "_show_filedialog"
        )

        self.connect("confirmed", self, "import_layer")

    func _show_filedialog():
        logv("browse pressed")

        var last_map_dir = Global.Editor.CurrentMapFile
        last_map_dir = last_map_dir.get_base_dir() if last_map_dir != null else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)

        var import_file

        # Linux needs special handling cause `show_open_dialog` isn't implemented on Linux for whatever reason
        if Global.World.get_node("/root/Global").IsLinux:
            var dialog_output = []
            var exit_code = OS.execute("zenity", [
                "--file-selection",
                "--modal",
                "--title", "Import image",
                "--file-filter", self.image_filter,
                "--filename", last_map_dir
            ], true, dialog_output, false)
            import_file = dialog_output[0]
        
        else:
            import_file = OS.show_open_dialog("Import image", self.image_filter, last_map_dir)

        if import_file != null:
            self.import_file_path = import_file
    
    # ---- self.import_file_path get/set
    func get_file_path():
        return self._import_file_path

    func set_file_path(path: String):
        logv('attempt to set image path to %s' % path)
        if path != null:
            logv('setting image path to %s' % path)
            self._import_file_path = path.strip_edges()
            self.file_lineedit.text = self._import_file_path


    # ---- self.image_filter get
    func _get_image_filter():
        match OS.get_name():
            "OSX":
                return "webp,jpeg,jpg,png"
            "X11":
                return "*.webp *.png *.jpeg *.jpg"
            _:
                return "All Images,*.png;*.jpg;*jpeg,PNG (*.png),*.png,JPEG (*.jpg),*.jpg;*jpeg,WebP (*.webp)"

    # ===== SIGNAL HANDLERS =====

    func on_file_selected(path):
        logv("file for import selected: %s" % path)
        self.import_file_path = path
        
    # ===== IMPORTING ======
    func import_layer():
        logv("import_layer called")
        if self.import_file_path == null:
            return

        var import_image = Image.new()
        var image_type = self.import_file_path.get_extension().to_lower().strip_edges()
        logv("image type is %s" % image_type)
        if not (image_type.to_lower() in ["png", "webp", "jpeg", "jpg"]):
            Global.Editor.Warn("Layer Import Error", "The file you selected is not a supported format.")
        
        var error = import_image.load(self.import_file_path)
        logv("imported %s" % self.import_file_path)
        logv("image is %s " % import_image)
        if error != OK:
            Global.Editor.Warn("Failed to import with code %d" % error)

        # Convert JPEG imports to have alpha channel, otherwise they won't be imported correctly
        if not (image_type in ["png", "webp"]):
            import_image.convert(Image.FORMAT_RGBA8)
        
        # Handle premultiplication
        if self.premult.pressed:
            logv("premultiply")
            import_image.premultiply_alpha()
        
        import_image.fix_alpha_edges()
        
        logv("resizing")
        match self.size_mode.get_selected_id():
            -1:
                logv("Invalid size mode, aborting")
                return
            # Actual Size
            0:  import_image = self.preprocess_actual_size(import_image)
            1:  import_image = self.preprocess_stretch(import_image)
            2:  import_image = self.preprocess_scale(import_image)

        logv("resized import image to %s" % import_image.get_size())

        var new_layer_index: int
        var layer_group_z = self.insert_layer.get_selected_id()
        logv("insertion layer group is %s" % layer_group_z)

        var filtered_zs = self.tree.get_group_z_array(layer_group_z)
        if len(filtered_zs) == 0:
            new_layer_index = layer_group_z + 1
            logv("no existing layers in group, creating at group Z + 1 (%d)" % new_layer_index)
        else:
            new_layer_index = filtered_zs.max() + 1
            logv("Existing layers in group, creating at Z: %d" % (filtered_zs.max() + 1))

        var layer_name = self.layer_name.text if self.layer_name.text != "" else "New Layer"
        logv("imported layer name is %s" % layer_name)

        

        var new_layer = RasterLayer.new(Global)
        new_layer.create_new(
            self.scontrol.curr_level_id, 
            new_layer_index,
            layer_name
        )
        logi("Importing layer from image file %s to layer %s" % [self.import_file_path, new_layer])

        new_layer.texture.set_data(import_image)
        logv("texture set")
        self.layerm.add_layer(new_layer)
        self.scontrol.set_active_layer(new_layer)

    # ===== IMAGE PROCESSING =====

    func preprocess_actual_size(source: Image):
        logv('preprocess_actual_size')
        var layer_size = Global.World.WorldRect.size / self.scontrol.RENDER_SCALE
        var source_size = source.get_size()

        var output_image

        if source_size.x < layer_size.x or source_size.y < layer_size.y:
            logi("source is smaller than target, blitting into output")
            output_image = Image.new()
            output_image.create(layer_size.x, layer_size.y, false, Image.FORMAT_RGBA8)
            var blit_pos = Vector2(
                    (layer_size.x / 2) - (source_size.x / 2), 
                    (layer_size.y / 2) - (source_size.y / 2)
                )

            output_image.blit_rect(
                source,
                Rect2(Vector2(0, 0), source_size),
                blit_pos
            )

            return output_image
           

        if (source_size > layer_size) or source_size == layer_size:
            logi("source is larger than target, cropping")
            source.crop(layer_size.x, layer_size.y)
            output_image = source

            return output_image

    func preprocess_stretch(source: Image):
        logv('preprocess_stretch')
        var layer_size = Global.World.WorldRect.size / self.scontrol.RENDER_SCALE
        source.resize(
            layer_size.x,
            layer_size.y
        )
        return source

    func preprocess_scale(source: Image):
        logv('preprocess_scale')
        var RESIZE_TARGET = {
            X_MAX = 0,
            Y_MAX = 1,
            EHH = 2
        }


        var layer_size = Global.World.WorldRect.size / self.scontrol.RENDER_SCALE
        var source_size = source.get_size()
        # Get aspect ratio
        var source_ratio = source_size.x / source_size.y

        var resize_target = RESIZE_TARGET.EHH
        var resize_val


        if (layer_size.x / source_ratio) <= layer_size.y:
            resize_target = RESIZE_TARGET.X_MAX
            resize_val = layer_size.x / source_ratio
        
        if (
            (layer_size.y * source_ratio) <= layer_size.x and 
            (layer_size.y * source_ratio) > resize_val
        ):
            resize_target = RESIZE_TARGET.Y_MAX
            resize_val = (layer_size.y * source_ratio)

        logv('resize target: %s' % resize_target)

        match resize_target:
            RESIZE_TARGET.X_MAX:
                source.resize(
                    layer_size.x,
                    clamp(floor(layer_size.x / source_ratio), 1, layer_size.y)
                )
            RESIZE_TARGET.Y_MAX:
                source.resize(
                    clamp(floor(layer_size.y * source_ratio), 1, layer_size.x),
                    layer_size.y
                )
            RESIZE_TARGET.EHH:
                logv("Unable to figure out how to resize image, giving up")

        return self.preprocess_actual_size(source)


class ExportDialog extends FileDialog:
    var Global
    var template

    var tree
    var layerm
    var scontrol
    var prefs

    var export_file_path

    var quality = 100
    var alpha

    var tree_container
    var align
    var file_tree_c
    var filter_button


    var file_extension setget , _get_file_extension

    const extension_indexes = ["invalid", "png", "webp", "jpeg", "invalid"]
    const extension_config = {
        "png": {
            "alpha": true,
            "quality": false
        },
        "webp": {
            "alpha": true,
            "quality": true
        },
        "jpeg": {
            "alpha": false,
            "quality": true
        },
        "invalid": {
            "alpha": false,
            "quality": false
        }
    }

    signal progress(progress)
    signal export_finished

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <ExportDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <ExportDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <ExportDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    # ===== BUILTINS =====
    func _init(global, layerm, scontrol, tree).():
        logv("init")
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol
        self.tree = tree
        self.prefs = Global.World.get_meta("painter_config")

        self.window_title = "Export Layer"
        self.name = "ExportDialog"
        
        self.template = ResourceLoader.load(Global.Root + "ui/export_dialog.tscn", "", true)
        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()
        logv("load template %s %s" % [instance, self])

        self.align = $"Align"

        self.set_anchor(0, 0, false, false)
        self.rect_position = Vector2(135, -10)
        self.rect_size = Vector2(800, 400)
        self.resizable = true
        logv("set sizes")

        self.mode = MODE_SAVE_FILE

        self.popup_exclusive = false
        self.size_flags_horizontal = SIZE_FILL
        self.size_flags_vertical = SIZE_FILL

        self.add_filter("*.png ; PNG images")
        self.add_filter("*.webp ; WebP images")
        self.add_filter("*.jpeg ; JPEG images")

        self.access = ACCESS_FILESYSTEM
        # Get file type option button
        self.filter_button = self.get_vbox().get_child(3).get_child(2)
    
        self._setup_split_tree()
        self._setup_preview()
       
        self.connect("about_to_show", self, "_on_about_to_show")
        self.connect("progress", self, "_on_progress")
        self.connect("file_selected", self, "_on_file_selected")

        # Disconnect default filter handler cause it's broken
        self.filter_button.disconnect(
            "item_selected",
            self.filter_button.get_signal_connection_list("item_selected")[0].target,
            "_filter_selected"
        )
        # Connect our own
        self.filter_button.connect(
            "item_selected",
            self,
            "_on_filter_selected"
        )
        self.filter_button.select(self.prefs.get_c_val("def_export_format") + 1)

        self.align.get_node("ExportSettings/AlphaC/Alpha").connect(
            "toggled",
            self,
            "_on_alpha_changed"
        )

        self.align.get_node("ExportSettings/QualityC/Quality").connect(
            "value_changed",
            self,
            "_on_quality_changed"
        )

        self.align.get_node("ExportSettings/AlphaC/Alpha").pressed = self.prefs.get_c_val("export_premultiplied")
        self.align.get_node("ExportSettings/QualityC/Quality").value = 100

        self._update_export_ui()

    func _process(delta):
        self._update_export_ui()
        
    func _setup_split_tree():
        logv("split tree setup")
        self.tree_container = HBoxContainer.new()
        self.tree_container.name = "TreeContainer"
        self.tree_container.visible = true
        self.tree_container.size_flags_vertical = SIZE_EXPAND_FILL
        self.tree_container.size_flags_horizontal = SIZE_EXPAND_FILL
        logv("tree container")
        
        self.remove_child(self.align)
        logv("align removed")
        
        self.file_tree_c = self.get_vbox().get_child(2)
        self.get_vbox().add_child_below_node(self.file_tree_c, self.tree_container)
        self.get_vbox().remove_child(self.file_tree_c)
        self.tree_container.add_child(self.file_tree_c)
        self.tree_container.add_child(self.align)
        self.file_tree_c.size_flags_horizontal = SIZE_EXPAND_FILL
        self.file_tree_c.get_children()[0].visible = true

        self.align.visible = true
        self.align.size_flags_stretch_ratio = 0.25
    
    func _setup_preview():
        logv("preview setup")
        # Load chequered background for preview
        var background_texture := ImageTexture.new()
        background_texture.load(Global.Root + "icons/preview_background.png")
        background_texture.set_size_override(Vector2(50, 50))
        self.align.get_node("Preview/PrevBox/Background").texture = background_texture

    func _update_export_ui():
        var ui_config = self.extension_config[self.file_extension]
        for key in ui_config.keys():
            match key:
                "alpha":
                    self.align.get_node("ExportSettings/AlphaC").modulate = Color.white if ui_config[key] else Color(1.0, 1.0, 1.0, 0.5)
                    self.align.get_node("ExportSettings/AlphaC/Alpha").editable = ui_config[key]
                "quality":
                    self.align.get_node("ExportSettings/QualityC").modulate = Color.white if ui_config[key] else Color(1.0, 1.0, 1.0, 0.5)
                    self.align.get_node("ExportSettings/QualityC/Quality").editable = ui_config[key]
        
    # ===== SIGNAL HANDLERS =====
    func _on_file_selected(path):
        self.export_file_path = path
        # Prevent dialog from being hidden immediately
        yield(get_tree(), "idle_frame")
        self.visible = true
        logv("file_selected: %s" % path)
        self.export_image()

    func _on_filter_selected(_val):
        self.invalidate()
        self._update_export_ui()

    func _on_alpha_changed(val):
        logv("alpha changed")
        self.alpha = val
    
    func _on_quality_changed(val):
        logv("quality changed")
        self.quality = val

    func _on_progress(progress):
        logv("Export Progress %2.2f/100" % progress)
        self.align.get_node("ProgressBar").value = progress

    func _on_about_to_show():
        self.export_file_path = null

        var active_texture: ImageTexture = self.scontrol.active_layer.texture
        self.align.get_node("Preview/PrevBox/PreviewRect").texture = active_texture.duplicate(false)
        self.align.get_node("Preview/PrevBox").ratio = (
            Global.World.WorldRect.size.x / 
            Global.World.WorldRect.size.y
        )
        logv("preview_texture set to [%s, %s]" % [self.scontrol.active_layer.texture, active_texture])

        self.align.get_node("ProgressBar").visible = false
        self.align.get_node("ProgressBar").self_modulate = Color.white
        logv(
            self.filter_button.get_item_text(
                self.filter_button.get_selected_id()
            )
        )

    # ===== EXPORT ======
    func export_image():
        logv("exporting layer to %s" % self.align.get_node("FileSelect/FilePath").text)
        
        var path = self.align.get_node("FileSelect/FilePath").text
        var image: Image = self.align.get_node("Preview/PrevBox/PreviewRect").texture.get_data()
        var image_size = image.get_size()
        var master = Global.Editor.owner

        self.align.get_node("ProgressBar").visible = true
        self.align.get_node("ProgressBar").self_modulate = Color(1.0, 1.0, 1.0, 1.0)

        logv("reversing alpha premult")
        logv("image resolution: %s" % image_size)
        
        var export_thread: Thread = Thread.new()
        export_thread.start(self, "_export_thread", image)
        
        yield(self, "export_finished")
        export_thread.wait_to_finish()

        self.align.get_node("ProgressBar").self_modulate = Color.lightgreen

    func _get_file_extension() -> String:
        if self.current_file != "" and self.current_file.get_extension() != "":
            if not self.current_file.get_extension().to_lower() in self.extension_indexes:
                return "invalid"
            else:
                return self.current_file.get_extension().to_lower()
        
        return self.extension_indexes[self.filter_button.get_selected_id()]
    
    ## _export_thread
    # Run in a separate thread to prevent the rather lengthy process of undoing Godot's
    # premultiplication from locking everything up
    func _export_thread(image: Image) -> int:
        logv('Export Thread started, image is %s' % image)
        var rows = image.get_size().y
        var code = 0

        if not self.alpha:
            image.lock()
            for row in range(0, rows):
                for column in range(0, image.get_size().x):
                    var pixel_color = image.get_pixel(row, column)
                    if pixel_color.a != 0.0:
                        pixel_color.r /= pixel_color.a
                        pixel_color.g /= pixel_color.a
                        pixel_color.b /= pixel_color.a
                        
                        image.set_pixel(row, column, pixel_color)
                
                self.emit_signal("progress", (100.0 / rows) * (row + 1))
            image.unlock()

        var export_extension = self.export_file_path.get_extension()
        match export_extension:
            "webp":
                logv("saving webp to %s, at quality %s" % [self.export_file_path, self.quality / 100])
                code = image.save_webp(self.export_file_path, self.quality)
            "png":
                logv("saving png to %s" % [self.export_file_path])
                code = image.save_png(self.export_file_path)
            "jpeg", "jpg":
                logv("saving jpeg to %s, at quality %s" % [self.export_file_path, self.quality])
                code = image.save_jpeg(self.export_file_path, self.quality)

        self.emit_signal("export_finished")
        return code

class LayerPropertiesDialog extends AcceptDialog:
    var Global
    var template 

    var tree
    var layerm
    var scontrol

    var ColorPalette

    var name_field: LineEdit
    var opacity_slider: HSlider
    var opacity_spinbox: SpinBox
    var tint

    var tint_color

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <LayerPropertiesDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <LayerPropertiesDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <LayerPropertiesDialog>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    # ===== BUILTIN =====
    

    func _init(global, layerm, scontrol, tree).():
        logv('init called')
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol
        self.tree = tree


        ColorPalette = load("res://scripts/ui/elements/ColorPalette.cs")

        self.template = ResourceLoader.load(Global.Root + "ui/layer_properties.tscn", "", true)
        var instance = template.instance()
        self.add_child(instance)
        self.window_title = instance.window_title
        self.rect_min_size = instance.rect_min_size
        self.size_flags_horizontal = SIZE_EXPAND_FILL
        self.size_flags_horizontal = SIZE_EXPAND_FILL
        instance.remove_and_skip()
        logv("template loaded")

        self.name_field = $"Align/NameEdit"
        self.tint = $"Align/TintEdit"
        self.opacity_slider = $"Align/Opacity/HSlider"
        self.opacity_spinbox = $"Align/Opacity/SpinBox"

        self.opacity_slider.share(self.opacity_spinbox)

        var palette_instance = ColorPalette.new(false)
        palette_instance.SetColor(Color(1, 1, 1, 1), false)
        self.tint.replace_by(palette_instance)
        self.tint = palette_instance
        self.tint.name = "TintEdit"
        self.tint.colorPicker.edit_alpha = false

        self.connect("about_to_show", self, "_on_about_to_show")
        self.connect("confirmed", self, "_on_confirm")
        self.tint.connect("color_changed", self, "_on_color_set")
    
    # ===== SIGNAL HANDLERS =====
    func _on_about_to_show():
        logv("about to show")
        var item = self.tree.layer_tree.active_item
        if item == null:
            return
        
        logv("setting name field to %s" % item.layer.layer_name)
        self.name_field.text = item.layer.layer_name
        self.tint.SetColor(item.layer.modulate)
        self.tint_color = item.layer.modulate

        self.opacity_slider.value = (item.layer.modulate.a * 100)

    func _on_color_set(color):
        logv("OIN")
        logv("new tint color set: %s" % color.to_html())
        self.tint_color = color

    func _on_confirm():
        var item = self.tree.layer_tree.active_item
        if item == null:
            return
            
        var old_layer_key = item.layer.embedded_key

        self.tint_color.a = (self.opacity_slider.value / 100) 
        logv("new color is %s" % self.tint_color)

        if item.layer.layer_name != self.name_field.text:
            item.layer.layer_name = self.name_field.text

        if item.layer.modulate != self.tint_color:
            item.layer.set_modulate(self.tint_color)

        item.layer.change_count += 1
        
        if old_layer_key != item.layer.embedded_key:
            self.scontrol.history_manager.record_layer_edit(old_layer_key, item.layer)
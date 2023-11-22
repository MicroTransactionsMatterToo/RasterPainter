class_name PainterUIC
var script_class = "tool"


const LOG_LEVEL = 4


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
        

class LayerTree extends Panel:
    var Global
    var template

    var layerm
    var control
    

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

    func _ready() -> void:
        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()

        $"ShadowLayers".remove_child($"ShadowLayers/ShadowLayer")

        self.control.connect("level_changed", self, "_on_level_change")
        self.layerm.connect("layer_created", self, "_on_layer_change")

    func _on_level_change(nlevel_id):
        logv("On Level Change")
        var new_level_layers = self.layerm.load_level_layers(nlevel_id)
        print(new_level_layers)
        new_level_layers.sort_custom(self.layerm, "sort_layers_desc")

        for entry in $"ShadowLayers".get_children():
            entry.visible = false

        for i in range(new_level_layers.size()):
            logv("FUCKING INDEX: " + str(i))
            if $"ShadowLayers".get_child(i) != null:
                logv("Reusing existing entry")
                $"ShadowLayers".get_child(i).layer = new_level_layers[i]
                $"ShadowLayers".get_child(i).visible = true
                continue
            else:
                logv("Creating new entry")
                var new_entry = LayerTreeItem.new(Global)
                new_entry.layer = new_level_layers[i]
                $"ShadowLayers".add_child(new_entry)
    
    func _on_layer_change(nlayer):
        self._on_level_change(self.control._current_level)


class LayerTreeItem extends PanelContainer:
    var Global
    var template
    var layer setget _set_layer, _get_layer
    var _layer

    var selected setget set_selected, get_selected
    var _selected

    var focused setget set_focused, get_focused
    var _focused

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

    func _set_layer(n_layer) -> void:
        self._layer = n_layer
        
        $"HB/Preview/LayerPreview".texture = self._layer.world_tex
        $"HB/LayerName".text = self._layer.layer_name
        $"HB/ZLevel".text = self._layer.z_index

    func _get_layer(): return self._layer
    
    func move_up():
        self._layer.z_index += 1
        self.emit_signal(
            "layer_num_changed", 
            self.layer, 
            self.layer.z_index - 1, 
            self.layer.z_index
        )

    func move_down():
        print("MOVING DOWN")
        var offset = 0
        var z_indexes = self.get_used_z_indexes()

        while z_indexes.has(self.layer.z_index - offset):
            offset -= 1

        

        self.call_deferred(
            "emit_signal",
            "layer_num_changed", 
            self.layer, 
            self.layer.z_index + 1, 
            self.layer.z_index
        )

    func get_used_z_indexes():
        var parent = self.get_parent()
        var z_indexes = []
        for child in parent.get_children():
            if child.visible:
                z_indexes.append(child.layer.z_index)
        
        z_indexes.sort()
        return z_indexes
    
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

    # --- self.focused get/set
    
    func get_focused() -> bool:
        return self._focused

    func set_focused(val: bool) -> void:
        if val:
            $"HB/Preview".self_modulate = Color(1, 1, 1, 1)
        else:
            $"HB/Preview".self_modulate = Color(1, 1, 1, 0)


class NewLayerDialog extends WindowDialog:
    var Global
    var template
    var layerm
    var control

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

    func create_layer():
        print("FUCKER")
        print($"Margins/Align/LayerName/LayerNameEdit".text)
        var test = self.layerm.create_layer(
            self.control._current_level, 
            $"Margins/Align/LayerNum/LayerNumEdit".value,
            $"Margins/Align/LayerName/LayerNameEdit".text
        )
        print(test)

        self.control.set_current_layer(test)

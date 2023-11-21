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
        $"MarginContainer/VBoxContainer/LayerTree".replace_by(layer_tree)

        self.rect_min_size.x = 256
        self.rect_position = Vector2(651, 0)

        self.size_flags_horizontal = SIZE_FILL
        self.size_flags_vertical = SIZE_FILL
        self.visible = true

        Global.Editor.get_child("Windows").add_child(self.dialog)

        $"MarginContainer/VBoxContainer/AddLayerButton".connect(
            "pressed",
            self,
            "show_layer_dialog"
        )
    
    func _exit_tree() -> void:
        self.queue_free()

    
    func show_layer_dialog():
        self.dialog.popup()
        

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


class LayerTreeItem extends HBoxContainer:
    var Global
    var template
    var layer setget _set_layer, _get_layer
    var _layer

    signal layer_num_changed(layer, from, to)

    func _init(global).() -> void:
        self.Global = global
        self.template = ResourceLoader.load(Global.Root + "ui/layertree_item.tscn", "", true)

        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()

    func _ready() -> void:
        # In-place replacement

        $"SelectButton".icon = load("res://ui/icons/misc/edit.png")
        $"DeleteButton".icon = load("res://ui/icons/misc/delete.png")

        $"LayerCtrl/MoveUp".connect("pressed", self, "move_up")
        $"LayerCtrl/MoveDown".connect("pressed", self, "move_down")

    func _set_layer(n_layer) -> void:
        self._layer = n_layer
        $"LayerPreview".texture = self._layer.world_tex
        $"LayerName".text = self._layer.layer_num

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
        # Set new Z-index
        self._layer.z_index -= 1
        # Shuffle siblings if needed
        var siblings = self.get_parent().get_children()
        var relevant_siblings = siblings.slice(self.get_index(), siblings.size())
        var new_index = null

        for sibling in relevant_siblings:
            if sibling.visible and sibling.layer.z_index > self.layer.z_index:
                new_index = sibling.get_index()
        
        if new_index != null:
            self.get_parent().move_child(self, new_index)

        self.emit_signal(
            "layer_num_changed", 
            self.layer, 
            self.layer.z_index + 1, 
            self.layer.z_index
        )

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
        var test = self.layerm.create_layer(
            self.control._current_level, 
            $"Margins/Align/LayerNum/LayerNumEdit".value
        )

        self.control.set_current_layer(test)

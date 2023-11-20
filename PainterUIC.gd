class_name PainterUIC
var script_class = "tool"


const LOG_LEVEL = 4


class LayerPanel extends Control:
    var Global
    var template

    var layer_tree

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

    func _init(global).() -> void:
        self.Global = global
        self.template = ResourceLoader.load(Global.Root + "ui/layerpanel.tscn", "", true)

    func _ready() -> void:
        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()

        self.layer_tree = self.find_node("LayerTree")
        logi(self.layer_tree)
        
        

class LayerTree extends Panel:
    var Global
    var template

    func _init(global).() -> void:
        self.Global = global
        self.template = ResourceLoader.load(Global.Root + "ui/layertree.tscn", "", true)

class LayerTreeItem extends HBoxContainer:
    var Global
    var template

    func _init(global).() -> void:
        self.Global = global
        self.template = ResourceLoader.load(Global.Root + "ui/layertree_item.tscn", "", true)

    func _ready() -> void:
        # In-place replacement
        var instance = self.template.instance()
        self.add_child(instance)
        instance.remove_and_skip()
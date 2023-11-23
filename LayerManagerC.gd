class_name LayerManagerC
var script_class = "tool"

# Principal class in charge of retreiving and creating ShadowLayers
# Does not hold state other than loaded layers
class LayerManager extends Object:
    var _layers = []
    var loaded_layers setget ,_get_loaded_layers

    signal layer_created(layer)

    var Global

    var ShadowLayerC
    var ShadowLayer

    const LOG_LEVEL = 4

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("[V] LM: ")
            print(msg)
        else:
            pass

    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("[I] LM: ")
            print(msg)
        else:
            pass

    func _init(global).() -> void:
        self.Global = global
        ShadowLayerC =	ResourceLoader.load(Global.Root + "ShadowLayerC.gd", "GDScript", true)
        ShadowLayer = 	load(Global.Root + "ShadowLayerC.gd").ShadowLayer

        self.name = "LayerManager"

    # Frees loaded layers and then itself
    func cleanup() -> void:
        for layer in self.loaded_layers:
            if is_instance_valid(layer):
                layer.queue_free()
        self.free()
    
    # getter
    func _get_loaded_layers() -> Array:
        return self._layers

    # Utility function that splits key from Global.World.EmbeddedTextures into it's parts
    func get_key_info(key: String):
        var split_key = key.split("|")
        if len(split_key) < 3:
            logi("Invalid embedded key")
            return null
        else:
            return {
                "level": int(split_key[0]),
                "layer": int(split_key[1]),
                "modulate": split_key[2],
                "name": split_key[3]
            }

    # Creates a new layer and returns it, or returns the existing layer matching
    # the parameters
    func create_layer(level_id, layer_num, lname = "New Layer"):
        logv("Attempting to create layer at [{lvl}, {lyr}]".format({
            "lvl": level_id,
            "lyr": layer_num
        }))
        # First try and load the layer, to avoid creating collisions
        var rlayer = self.load_layer(level_id, layer_num)

        if rlayer != null:
            logv("Aborting creation, layer already exists: " + str(rlayer))
            return rlayer

        
        rlayer = ShadowLayer.new(Global.World)
        rlayer.create_new(level_id, layer_num, lname)
        logv("Created layer: " + str(rlayer))
        self._layers.append(rlayer)

        self.emit_signal("layer_created", rlayer)

        return rlayer


    # Finds all existing layers for the given level ID, and then
    # loads those not already loaded.
    func load_level_layers(level_id) -> Array:
        logv("Loading layers for level: " + str(level_id))
    
        var level_layers = []
        
        for key in Global.World.EmbeddedTextures.keys():
            var key_info = self.get_key_info(key)
            if int(key_info["level"]) == level_id:
                var nlayer = self.load_layer(level_id, key_info["layer"])
                level_layers.append(nlayer)
        
        for layer in self.loaded_layers:
            if !level_layers.has(layer) and layer.level_id == level_id:
                level_layers.append(layer)

        level_layers.sort_custom(self, "sort_layers_desc")

        return level_layers


    # Attempts to load the given layer. 
    # Returns null if layer does not exist
    func load_layer(level_id, layer_num):
        logv("Get layer Level: {lvl}, Layer: {lyr}".format({
            "lvl": level_id,
            "lyr": layer_num
        }))
        # Check to see if we've already loaded the layer
        for layer in self.loaded_layers:
            if  (
                layer.level_id == level_id and
                layer.layer_num == layer_num
            ):
                logv("Layer {lyr} already loaded".format({"lyr": str(layer)}))
                return layer
        
        # Check to see if it's been previously saved
        for key in Global.World.EmbeddedTextures.keys():
            var key_info = self.get_key_info(key)
            # Check to see if key was valid, to avoid conflicts with future uses
            # of EmbeddedTexture
            if key_info == null:
                continue
            
            if (
                key_info["level"] == level_id   and
                key_info["layer"] == layer_num
            ):
                logv("Loading layer with key: " + str(key))
                var nlayer = ShadowLayer.new(Global.World)
                nlayer.create_from_embedded_key(key)
                self._layers.append(nlayer)
                return nlayer
        
        return null
    
    # Creates an invisible text object with a unique node_id on the given level
    func create_level_id(level):
        logv("Generating new level id for " + level.Label)
        var new_text = level.Texts.CreateText()
        new_text.SetFontColor(Color("#DEADBEEF"))
        new_text.SetFont("Libre Baskerville", 20)
        # Generate a random number for node_id, between 100000 and 200000
        var text_id = 100000 + (randi() % 100000)
        new_text.set_meta("node_id", text_id)
        return text_id
    
    # Attempts to find the ID for the current level.
    # Automatically creates ID if it can't find one
    func get_level_id(level):
        var level_ids = self.get_level_ids()
        for key in level_ids.keys():
            if level == level_ids[key]:
                return key
        
        var key = self.create_level_id(level)
        return key
        
    # Gets a level by ID
    func get_level_by_id(id):
        for level in Global.World.AllLevels:
            for textChild in level.Texts.get_children():
                if textChild.GetNodeID() == id:
                    return level

    # Returns a dict of all levels, mapped as id: Level
    func get_level_ids() -> Dictionary:
        var id_nodes = {}
        for level in Global.World.AllLevels:
            for textChild in level.Texts.get_children():
                if textChild.fontColor == Color("#DEADBEEF"):
                    id_nodes[textChild.get_meta("node_id")] = level
        
        return id_nodes

    # Returns an array of the Z-index of all layers for the given level ID, descending
    func z_indexes(level_id):
        var rval = []

        for layer in self.loaded_layers:
            if layer.level_id == level_id:
                rval.append(layer.z_index)
        
        rval.sort()
        rval.invert()

        return rval
    
        
    
    # Function for sorting layers by z_index
    func sort_layers(asc: bool):
        if asc:
            self._layers.sort_custom(LayerManager, "sort_layers_asc")
    
    # Sorts layers in ascending order
    static func sort_layers_asc(a, b):
        if a.layer_num < b.layer_num:
            return true
        return false

    static func sort_layers_desc(a, b):
        if a.layer_num > b.layer_num:
            return true
        return false
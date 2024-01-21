class_name LayerManagerC
var script_class = "tool"

# Principal class in charge of retreiving and creating RasterLayers
# Does not hold state other than loaded layers
class LayerManager extends Object:
    var loaded_layers := {}
    

    var Global
    var RasterLayerC
    var RasterLayer

    signal layer_added(new_layer)
    signal layer_modified(layer)

    const LOG_LEVEL = 4

    # ===== LOGGING =====

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <LayerManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <LayerManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <LayerManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    # ===== BUILTIN =====
    func _init(global).() -> void:
        logv("init")
        self.Global = global
        # Load classes
        RasterLayerC =	ResourceLoader.load(Global.Root + "RasterLayerC.gd", "GDScript", true)
        RasterLayer = 	load(Global.Root + "RasterLayerC.gd").RasterLayer

        self.name = "LayerManager"
    
    func cleanup() -> void:
        logv("Cleanup called, freeing layers")
        for layer in self.loaded_layers.values():
            if is_instance_valid(layer):
                layer.queue_free()

        if Global.API != null:
            for item in Global.API.HistoryApi.history:
                if item._record.MAGIC == "RRCRD":
                    item._record.free()
                    logv("Freed %s" % item)
            for item in Global.API.HistoryApi.redo_history:
                if item._record.MAGIC == "RRCRD":
                    item._record.free()
                    logv("Freed %s" % item)

            logv("History Queues: %s, %s" % [Global.API.HistoryApi.history, Global.API.HistoryApi.redo_history])
        logv("Layers freed, freeing self")
        self.free()

    ## get_key_info
    # Converts the given RasterLayer key into a dictionary
    func get_key_info(key: String):
        var split_key = key.split("|")
        if len(split_key) < 3:
            logi("Invalid embedded key")
            return null
        else:
            return {
                "level": int(split_key[0]),
                "z_index": int(split_key[1]),
                "modulate": split_key[2],
                "name": split_key[3],
                "uuid": split_key[4]
            }
    
    # ===== LAYERS =====

    ## add_layer
    # Attempts to add the given layer to managed layers. 
    func add_layer(new_layer):
        logv("Adding layer %s to managed layers" % new_layer)

        if new_layer.uuid in self.loaded_layers.keys():
            logd("Layer %s already managed, ignoring" % new_layer)
            return false
        
        self.loaded_layers[new_layer.uuid] = new_layer
        self.emit_signal("layer_added", new_layer)
        new_layer.connect("layer_modified", self, "on_layer_changes")

        return true
    
    ## remove_layer
    # Attempts to remove the given layer, removing it from managed layers
    # and then freeing the memory used
    func remove_layer(layer):
        if layer == null:
            logv("layer was null, not deleting")
            return
        
        logv("remove_layer called: %s" % layer)
        var is_layer_loaded = self.loaded_layers.has(layer.uuid)
        if is_layer_loaded:
            logv("layer was managed by layer_manager, removing from loaded layers")
            var deleted = self.loaded_layers.erase(layer.uuid)
            logv("layer removed: %s" % deleted)
        
    ## load_layer
    # Attempts to load a RasterLayer from EmbeddedTextures using the given key.
    # Returns the loaded layer, or null if loading failed
    func load_layer(layer_key: String):
        logv("Loading layer with key: %s" % layer_key)
        
        var key_info = self.get_key_info(layer_key)
        if key_info["uuid"] in self.loaded_layers.keys():
            logv("Layer already loaded")
            return self.loaded_layers[key_info["uuid"]]
        
        for key in Global.World.EmbeddedTextures.keys():
            var emb_key = self.get_key_info(key)
            if (
                emb_key["uuid"] == key_info["uuid"] and
                Global.World.EmbeddedTextures[key] != null
            ):
                logv("Found key in textures, loading")
                var new_layer = RasterLayer.new(Global)
                logv("instance created %s" % new_layer)
                new_layer.create_from_key(key)
                logv("created from key")
                self.add_layer(new_layer)
                logv("added")

                return new_layer
        
        logv("Unable to load key %s" % layer_key)
        return null

    ## get_layers_in_level
    # Returns an array of all RasterLayers with their `level_id` set to the
    # given ID
    func get_layers_in_level(level_id):
        logv("Fetching layers for level %s" % level_id)
        var level_layers := []

        for key in Global.World.EmbeddedTextures.keys():
            if Global.World.EmbeddedTextures[key] == null:
                logv("Ignoring %s, value is null" % key)
                continue
            
            var key_info = self.get_key_info(key)
            if key_info["level"] == level_id:
                self.load_layer(key)

        logv("got embedded entries")

        for layer in self.loaded_layers.values():
            if layer.level_id == level_id:
                level_layers.append(layer)

        logv("completed appending")
        return level_layers

    func get_layer_by_uuid(layer_uuid):
        return self.layer_filter(self, "uuid_lambda", [layer_uuid])[0]

    ## layer_map
    # `map` implementation for layers
    func layer_map(instance: Object, funcname: String, extra_args = []):
        var map_result := []
        var map_func = funcref(instance, funcname)
        if not map_func.is_valid():
            return null
        
        for layer in self.loaded_layers.values():
            var result = map_func.call_funcv([layer] + extra_args)
            map_result.append(result)
        
        return map_result

    ## layer_filter
    # `filter` implementation for layers
    func layer_filter(instance: Object, funcname: String, extra_args = []):
        var filter_result := []
        var filter_func = funcref(instance, funcname)
        if not filter_func.is_valid():
            return null
        
        for layer in self.loaded_layers.values():
            if filter_func.call_funcv([layer] + extra_args):
                filter_result.append(layer)
        
        return filter_result
    
    ## layer_z_indexes
    # Returns a sorted array containing the Z-indexes of all raster layers in the 
    # level identified by the level_id
    func layer_z_indexes(level_id) -> Array:
        var z_idxs := []
        for layer in self.layer_filter(self, "lid_lambda", [level_id]):
            z_idxs.append(layer.z_index)

        z_idxs.sort()
        z_idxs.invert()

        return z_idxs

    # ====== LEVELS ======
    ## create_level_id
    # Creates an invisible text object with a unique node_id on the given level
    func create_level_id(level: Object):
        logv("Generated new level ID for %s" %level.Label)

        var new_text = level.Texts.CreateText()
        new_text.SetFontColor(Color("#DEADBEEF"))
        new_text.SetFont("Libre Baskerville", 20)

        var text_id = 100000 + (randi() % 100000)
        new_text.set_meta("node_id", text_id)
        return text_id
    
    func get_level_id(level: Object, create_if_missing = true):
        var level_ids := self.get_level_ids()

        for key in level_ids.keys():
            if level == level_ids[key]:
                return key
        
        if create_if_missing:
            logd("Creating level_id as none was found")
            var key = self.create_level_id(level)
            return key

    ## get_level_ids
    # Returns a dictionary with levels mapped to their IDs
    func get_level_ids() -> Dictionary:
        var id_nodes = {}
        for level in Global.World.AllLevels:
            for textChild in level.Texts.get_children():
                if textChild.fontColor == Color("#DEADBEEF"):
                    id_nodes[textChild.get_meta("node_id")] = level
        
        return id_nodes

    # ====== SIGNAL ======
    func on_layer_changes(layer):
        self.emit_signal("layer_modified", layer)

    # ====== SORTING ======
    static func sort_layers_asc(a, b) -> bool:
        if a.z_index < b.z_index:
            return true
        return false

    static func sort_layers_desc(a, b) -> bool:
        if a.z_index > b.z_index: 
            return true
        return false

    # == SHIT THAT SHOULD BE LAMBDAS ==
    func lid_lambda(layer, level_id): return layer.level_id == level_id
    func uuid_lambda(layer, uuid): return layer.uuid == uuid
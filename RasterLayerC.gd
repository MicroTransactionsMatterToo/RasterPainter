var script_class = "tool"

### RasterLayer
# Probably better called RasterLayer, this class handles rendering and storage of raster textures
class RasterLayer extends Sprite:
    # Level UUID this layer is associated with
    var level_id: int setget set_level_id, get_level_id
    var _level_id

    # Display name for this layer
    var layer_name: String setget set_layer_name, get_layer_name
    var _layer_name: String

    # UUID for this layer
    var uuid: String setget , get_uuid
    var _uuid: String

    var embedded_key: String setget , get_embedded_key

    var change_count = 0

    var Global

    # Emitted when `z_index` is changed
    signal z_index_change(old, new, obj)
    # Emitted when layer is moved to a different level
    signal level_change(old, new, obj)
    # Emitted when name is change
    signal name_change(old, new, obj)
    # Emitted on any change
    signal layer_modified(obj)

    # Constant for scaling texture to correct size
    var RENDER_SCALE = 2
    const LOG_LEVEL = 4

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <RasterLayer>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <RasterLayer>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <RasterLayer>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    # ============= BUILTINS ================

    func _init(global).() -> void:
        logv("init")
        self.Global = global
        var prefs = Global.World.get_meta("painter_config")
        RENDER_SCALE = prefs.get_c_val("render_scale")

        # Set material to ensure correct rendering of transparency
        self.material = CanvasItemMaterial.new()
        self.material.blend_mode = CanvasItem.BLEND_MODE_MIX

        self.centered = false
        self.scale = Vector2(RENDER_SCALE, RENDER_SCALE)
        self.rect_scale = Vector2(RENDER_SCALE, RENDER_SCALE)

    func _process(delta):
        if self.change_count > 0:
            logv("RasterLayer changed")
            for key in Global.World.EmbeddedTextures.keys():
                var key_info = self.decode_key(key)
                if key_info.uuid == self.uuid and key != self.embedded_key:
                    logv("Found matching UUID, key was %s" % key)
                    Global.World.EmbeddedTextures[key] = null

        self.change_count = 0

    func _to_string() -> String:
        return "[RasterLayer \"{name}\" <Z: {z}, Level: {lvl}, UUID: {uuid}> @ id]".format({
            "z": self.z_index,
            "lvl": self.level_id,
            "id": self.get_instance_id(),
            "name": self.layer_name,
            "uuid": self.uuid
        })

    func get_name() -> String:
        return str(self)

    func queue_free() -> void:
        logd("queue_free called")
        .queue_free()

    func delete():
        Global.World.EmbeddedTextures[self.embedded_key] = null
        self.queue_free()

    # ============= INSTANTIATION ================
    
    ### create_new
    # Creates an entirely new, empty RasterLayer with the given parameters
    func create_new(level_id, z_index, layer_name, skip_texture = false):
        logv("Creating new RasterLayer @ Level: %s, Z: %s, name: %s" % [
            level_id, 
            z_index, 
            layer_name
        ])

        

        # Set attributes
        self._level_id = level_id
        .set_z_index(z_index)
        self._layer_name = layer_name

        self._uuid = "%x" % (200000 + (randi() % 100000))

        if !skip_texture:
            # Create a new texture
            var texture_size = Vector2(
                Global.World.WorldRect.size.x / RENDER_SCALE,
                Global.World.WorldRect.size.y / RENDER_SCALE
            )

            var empty_image = Image.new()
            empty_image.create(
                texture_size.x,
                texture_size.y,
                false,
                Image.FORMAT_RGBA8
            )

            var new_texture = ImageTexture.new()
            new_texture.create_from_image(empty_image)
            if new_texture != null: logv("New texture created")
                
            .set_texture(new_texture)
    
    ### create_from_key
    # Creates a raster layer from a texture stored in `World.EmbeddedTextures`, using `key`
    func create_from_key(key: String):
        logv("Creating RasterLayer from key %s" % key)
        var key_data = key.split("|")

        self._level_id      = int(key_data[0])
        self.modulate       = Color(key_data[2])
        self._layer_name    = key_data[3]
        self._uuid          = key_data[4]
        .set_z_index(int(key_data[1]))

        .set_texture(Global.World.EmbeddedTextures[key])
        self.texture.set_size_override(
            Vector2(
                Global.World.WorldRect.size.x / RENDER_SCALE,
                Global.World.WorldRect.size.y / RENDER_SCALE
            )
        )

    # ======== GETTERS/SETTERS =========

    # ---- self.level_id get/set
    func set_level_id(new_id: int):
        logv("Moving layer \"%s\" from level %s to %s" %[
            str(self),
            self.level_id,
            new_id
        ])

        var old_key = self.embedded_key
        var old_level = self._level_id
        self._level_id = new_id

        Global.World.EmbeddedTextures[old_key] = null
        Global.World.EmbeddedTextures[self.embedded_key] = self.texture

        self.change_count += 1

        self.emit_signal("level_change", old_level, new_id, self)
        self.emit_signal("layer_modified", self)

    func get_level_id() -> int:
        return self._level_id

    # ---- self.layer_name get/set

    func set_layer_name(new_name: String):
        logv("Setting layer name to %s" % new_name)

        var old_key = self.embedded_key
        var old_name = self._layer_name
        self._layer_name = new_name
        
        Global.World.EmbeddedTextures[old_key] = null
        Global.World.EmbeddedTextures[self.embedded_key] = self.texture

        self.change_count += 1

        self.emit_signal("name_change", old_name, new_name, self)
        self.emit_signal("layer_modified", self)

    func get_layer_name() -> String:
        return self._layer_name

    # ---- self.z_index set/get

    func set_z_index(value):
        logv("Setting layer Z-index from %d to %d" % [self.z_index, value])

        var old_key = self.embedded_key
        var old_z = self.z_index
        .set_z_index(value)

        Global.World.EmbeddedTextures[old_key] = null
        Global.World.EmbeddedTextures[self.embedded_key] = self.texture

        self.change_count += 1

        self.emit_signal("z_index_change", old_z, value, self)
        self.emit_signal("layer_modified", self)

    # ---- self.modulate set/get
    func set_modulate(color: Color):
        logv("Setting layer modulate to %s" % color)

        var old_key = self.embedded_key
        .set_modulate(color)

        Global.World.EmbeddedTextures[old_key] = null
        Global.World.EmbeddedTextures[self.embedded_key] = self.texture

        self.change_count += 1

        self.emit_signal("layer_modified", self)

    # ---- self.uuid get

    func get_uuid() -> String:
        return self._uuid

    # ---- self.embedded_key get
    func get_embedded_key() -> String:
        return "{level_id}|{layer_num}|{modcol}|{name}|{uuid}".format({
            "level_id": self._level_id,
            "layer_num": self.z_index,
            "modcol": "#" + self.modulate.to_html(true),
            "name": self.layer_name,
            "uuid": self.uuid
        })

    #
    func decode_key(key):
        var key_data = key.split("|")

        var data = {
            "level_id": int(key_data[0]),
            "modulate": Color(key_data[2]),
            "layer_name": key_data[3],
            "uuid": key_data[4],
            "z_index": int(key_data[1])
        }
        
        return data
var script_class = "tool"

class ShadowLayer extends Sprite:
    var layer_num: int setget set_layer_num, get_layer_num
    var _layer_num: int
    var level_id: int setget set_level_id, get_level_id
    var _level_id: int
    var world_tex: ImageTexture setget set_worldtex, get_worldtex
    var _world_tex: ImageTexture
    var layer_name: String setget set_lname, get_lname
    var _layer_name: String = "New Layer"

    var World 



    const LAYER_SCALE = 2

    func _init(world) -> void:
        self.World = world
        self.mouse_filter = Control.MOUSE_FILTER_IGNORE
        
        self.material = CanvasItemMaterial.new()
        self.material.blend_mode = CanvasItem.BLEND_MODE_PREMULT_ALPHA
        self.centered = false
        self.scale = Vector2(LAYER_SCALE, LAYER_SCALE)
        self.rect_scale = Vector2(LAYER_SCALE, LAYER_SCALE)

        # self.texture.storage = ImageTexture.STORAGE_COMPRESS_LOSSLESS
        # self.texture.flags = ImageTexture.FLAGA


    func queue_free() -> void:
        print("[ShadowLayer]: Freeing")
        .queue_free()

    func _enter_tree() -> void:
        
        printraw("WORLD IS: ")
        print(self.World.WorldRect.size)


    # Embedded Key format
    # LevelID|Layer Number|Modulate Color (hex)
    # Example
    # afd2113|-50|#ff00ff|0.5

    func create_from_embedded_key(key: String):
        var split_key = key.split("|")
        
        self.level_id = int(split_key[0])
        self.layer_num = int(split_key[1])
        self.modulate = Color(split_key[2])
        self._layer_num = split_key[3]

        self.world_tex = World.EmbeddedTextures[key]
        self.name = str(self)
        

    func create_new(lvl_id, layer_n, lname = "New Layer"):
        var texture_size = Vector2(
            self.World.WorldRect.size.x / LAYER_SCALE,
            self.World.WorldRect.size.y / LAYER_SCALE
        )

        var ntexture = ImageTexture.new()
        var nimage = Image.new()
        nimage.create(
            texture_size.x,
            texture_size.y,
            false,
            Image.FORMAT_RGBA8
        )
        ntexture.create_from_image(nimage)
        self._level_id = lvl_id
        self._layer_num = layer_n
        self.z_index = layer_n
        self.layer_name = lname

        self.world_tex = ntexture
        self.name = str(self)

    func get_embedded_key() -> String:
        return "{level_id}|{layer_num}|{modcol}|{name}".format({
            "level_id": self._level_id,
            "layer_num": self.layer_num,
            "modcol": "#" + self.modulate.to_html(true),
            "name": self.layer_name
        })

    # --- self.level_id get/set

    func set_level_id(new_level_id: int) -> void:
        var old_worldtex_key = self.get_embedded_key()
        # Copy current texture
        var current_texture = self.world_tex.duplicate(false)
        # Set layer number
        self._level_id = new_level_id
        # Erase old key
        World.EmbeddedTextures.erase(old_worldtex_key)
        # Equivalent to Global.World.EmbeddedTextures[self.get_embedded_key()] = current_texture
        self.world_tex = current_texture

    func get_level_id() -> int:
        return self._level_id

    # --- self.layer_num get/set

    func set_layer_num(new_layer: int) -> void:
        var old_worldtex_key = self.get_embedded_key()
        # Copy current texture
        var current_texture = self.texture.duplicate(false)
        # Set layer number
        self._layer_num = new_layer
        self.z_index = new_layer
        # Erase old key
        World.EmbeddedTextures.erase(old_worldtex_key)
        # Equivalent to Global.World.EmbeddedTextures[self.get_embedded_key()] = current_texture
        self.texture = current_texture

    func get_layer_num() -> int:
        return self._layer_num

    # --- self.texture get/set

    func set_worldtex(val: ImageTexture) -> void:
        if val != null:
            self._world_tex = val
            self.texture = self._world_tex

    func get_worldtex() -> ImageTexture:
        if self._world_tex == null:
            var texture_size = Vector2(
                World.WorldRect.size.x / LAYER_SCALE,
                World.WorldRect.size.y / LAYER_SCALE
            )
            print(texture_size)
            var ntexture = ImageTexture.new()
            # ntexture.storage = ImageTexture.STORAGE_COMPRESS_LOSSLESS
            var nimage = Image.new()
            nimage.create(
                texture_size.x,
                texture_size.y,
                false,
                Image.FORMAT_RGBA8
            )
            ntexture.create_from_image(nimage)
            self.world_tex = ntexture
            return self._world_tex
        else:
            return self._world_tex

    # --- self.layer_name get/set
    func set_lname(val: String):
        # Remove characters that will cause issues
        val = val.replace("|", "").replace("\\", "")
        self._layer_name = val

    func get_lname() -> String:
        return self._layer_name


        
    func _to_string() -> String:
        return "[ShadowLayer \"{name}\" <Z: {z}, Level: {lvl}> @ {id}]".format({
            "z": self.layer_num,
            "lvl": self.level_id,
            "id": self.get_instance_id(),
            "name": self.layer_name
        })
    
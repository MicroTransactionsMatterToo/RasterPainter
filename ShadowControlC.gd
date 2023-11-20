class_name ShadowControlC
var script_class = "tool"
var SC = ShadowControl

class ShadowControl extends Control:
    var Global

    var _viewport: Viewport
    var _viewport_tex: ViewportTexture
    var _viewport_rend: TextureRect
    var _viewport_size_override
    var _viewport_mod: Node2D
    
    var current_layer setget set_current_layer, get_current_layer
    var _current_layer
    var _layer_num

    var _current_level
    var _level_layers
    # Node2D that contains the current levels shadow layers
    # Excludes the layer currently being edited
    var _level_cont

    var _prev_mouse_pos
    var _is_painting: bool = false
    var _stroke_finished: bool = false
    var _should_paint: bool = false

    var _pen: Node2D
    var _brushmanager
    var _layerm

    

    signal stroke_finished(position)
    signal stroke_started(position)

    signal level_changed(level)
    signal layer_changed(layer)

    const LOG_LEVEL = 4
    const RENDER_SCALE = 2

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("[V] SC: ")
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("[I] SC: ")
            print(msg)
        else:
            pass

    func _init(global, brushmanager, layermanager).() -> void:
        self.Global = global

        self._brushmanager = brushmanager
        self._layerm = layermanager

        self._layer_num = -50
        self._current_level = Global.World.Level.ID

    

    func _ready() -> void:
        logi("Setting up ShadowControl")
        self.mouse_filter = Control.MOUSE_FILTER_PASS

        self.size_flags_horizontal = SIZE_EXPAND
        self.size_flags_vertical = SIZE_EXPAND

        logv("Creating viewport")
        self._viewport = Viewport.new()
        self._viewport.name = "ViewportDrawing"

        self._viewport.size = Global.World.WorldRect.size / RENDER_SCALE
        self._viewport.set_size_override(
            true, 
            Global.World.WorldRect.size
        )
        self._viewport.size_override_stretch = true
        # VisualServer.set_default_clear_color(Color(1, 0, 1, 0))

        self._viewport.usage = Viewport.USAGE_3D
        self._viewport.disable_3d = true
        self._viewport.hdr = false
        # self._viewport.render_target_clear_mode = Viewport.CLEAR_MODE_ONLY_NEXT_FRAME
        self._viewport.transparent_bg = true

        self._viewport.gui_disable_input = true

        self._viewport.render_target_v_flip = true
        logv("Created viewport")

        logv("Creating viewport TextureRect")
        self._viewport_rend = TextureRect.new()
        self._viewport_rend.mouse_filter = Control.MOUSE_FILTER_IGNORE
        self._viewport_rend.material = CanvasItemMaterial.new()
        self._viewport_rend.material.blend_mode = CanvasItem.BLEND_MODE_PREMULT_ALPHA
        self._viewport_rend.set_size(Global.World.WorldRect.size, false)
        self._viewport_rend.rect_scale = Vector2(RENDER_SCALE, RENDER_SCALE)
        self._viewport_rend.name = "ViewportRender"
        logv("Created viewport TextureRect")
        
        self._viewport_tex = self._viewport.get_texture()
        self._viewport_rend.set_texture(self._viewport_tex)
        
        self._viewport_mod = Node2D.new()
        self._viewport_mod.name = "ViewportMod"
        
        
        
        logv("Creating pen")
        self._pen = Node2D.new()
        self._pen.name = "Pen"
        self._pen.connect("draw", self, "_on_draw")
        self._viewport.add_child(self._pen)
        self._current_level = self._layerm.get_level_id(Global.World.Level)
        self._current_layer = self._layerm.create_layer(
            self._current_level,
            self._layer_num
        )

        logv("Creating level container")
        self._level_cont = Node2D.new()
        self._level_cont.name = "LevelContainer"
    

        logv("Adding children")
        self.add_child(self._viewport_mod)
        self.add_child(self._level_cont)
        self.add_child(self._current_layer)
        self.add_child(self._viewport)
        self._viewport_mod.add_child(self._viewport_rend)
        # self.add_child(self._viewport_rend)

    func _process(delta: float) -> void:
        if Global.Header.data == null:
            if self._layerm.get_level_id(Global.World.Level) != self._current_level:
                self._on_level_change()

            self._viewport_rend.update()

    func _on_tool_input(event: InputEvent) -> void:
        if event is InputEventMouseButton:
            if event.button_index == BUTTON_LEFT and event.pressed:
                self._should_paint = true
                self._pen.update()
            elif event.button_index == BUTTON_LEFT and !event.pressed:
                self._should_paint = false
                self._prev_mouse_pos = null
                self._pen.update()
            else:
                self._should_paint = false
                self._prev_mouse_pos = null
                self._pen.update()
        if self._should_paint:
            self._pen.update()

    func _on_draw() -> void:
        var mouse_pos = get_local_mouse_position()
        
        if self._brushmanager.current_brush == null:
            return
        
        if self._should_paint:
            if !self._is_painting:
                logv("Stroke started")
                self.emit_signal("stroke_started", mouse_pos)
                self._prev_mouse_pos = mouse_pos
            self._is_painting = true
            self._brushmanager.current_brush.paint(_pen, mouse_pos, self._prev_mouse_pos)
        else:
            if self._is_painting:
                logv("Stroke finished")
                self.emit_signal("stroke_finished", mouse_pos)
                self._on_stroke_finish()
                self._stroke_finished = true
                self._is_painting = false
        
        self._prev_mouse_pos = mouse_pos

    func _on_stroke_finish() -> void:
        logv("Blending new stroke to layer")
        var viewport_render: Image = self._viewport_tex.get_data()

        var updated_region = viewport_render.get_used_rect()

        var shadow_render = self._current_layer.texture.get_data()
        shadow_render.blend_rect(
            viewport_render,
            updated_region,
            updated_region.position
        )
        logv("Blending finished")
        logv("Blending res: {x}, {y}".format({
            "x": shadow_render.get_width(),
            "y": shadow_render.get_height()
        }))
        
        self._current_layer.texture.set_data(shadow_render)

        self._brushmanager.current_brush.on_stroke_end()

        logv("Saving to key: " + self._current_layer.get_embedded_key())
        Global.World.EmbeddedTextures[self._current_layer.get_embedded_key()] = self._current_layer.texture.duplicate(false)

    func set_current_layer(nlayer) -> void:
        logv("Replacing ")
        self.print_tree_pretty()
        self.remove_child(self._current_layer)
        self._current_layer = nlayer
        self.add_child(nlayer)

    func get_current_layer():
        return self._current_layer
    
    func _on_level_change():
        logv("Layer changed from {old} to {new}".format({
                "old": self._current_level,
                "new": self._layerm.get_level_id(Global.World.Level)
            }))

        self._current_level = self._layerm.get_level_id(Global.World.Level)

        var level_layers = self._layerm.load_level_layers(self._current_level)
        if len(level_layers) == 0:
            logv("Level {lvl} has no existing layers, creating new at -50".format({
                "lvl": self._current_level
            }))
            self._layer_num = -50
            self.current_layer = self._layerm.create_layer(self._current_level, self._layer_num)
        elif len(level_layers) == 1:
            self.current_layer = level_layers[0]
        else:
            # TODO: set current layer to the upper most
            self.current_layer = level_layers[0]


        logv("Clearing _level_cont children")
        for child in self._level_cont.get_children():
            self._level_cont.remove_child(child)

        for layer in self._layerm.load_level_layers(self._current_level):
            if layer.level_id != self.current_layer.level_id:
                self._level_cont.add_child(layer)
        
        self.emit_signal("level_changed", self.current_layer)
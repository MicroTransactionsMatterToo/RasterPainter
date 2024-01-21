class_name PreferencesC

var script_class = "tool"

const LOG_LEVEL = 4

class Preferences extends ScrollContainer:
    var Global

    var template

    var ColorPalette
    var Cache

    var _loading_complete

    var config_file

    var config_nodes := []

    const CONFIG_FILE_DIR = "user://RasterPainter"
    const CONFIG_FILE_PATH = "user://RasterPainter/config.json"

    var config_dict := {}
    var config_defaults = {
        "def_brush_col": Color(1, 1, 1, 1),
        "def_size_val": 200,
        "def_export_format": 0,
        "export_premultiplied": false,
        "num_undo_states": 10,
        "render_scale": 2,
        "use_user_layers": true,
        "disable_lib_warning": false
    }

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <Preferences>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <Preferences>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <Preferences>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    # ===== BUILTINS =====
    func _init(global).():
        self.Global = global

        logv("Loading UI template")
        self.template = ResourceLoader.load(Global.Root + "ui/preferences.tscn", "", true)
        var instance = template.instance()
        self.add_child(instance)
        instance.remove_and_skip()
        logv("Template loaded")

        ColorPalette = load("res://scripts/ui/elements/ColorPalette.cs")
        Cache = load("res://scripts/core/Cache.cs")

        self.size_flags_horizontal = SIZE_EXPAND_FILL
        self.size_flags_vertical = SIZE_EXPAND_FILL

        self._load_config()

        if (Global.World.WorldRect.size.x / self.get_c_val("render_scale") > 16384 or
            Global.World.WorldRect.size.y / self.get_c_val("render_scale") > 16384):
            for i in range(3, 10):
                logv("Trying render scale of %d" % i)
                if (Global.World.WorldRect.size.x / i < 16384 and
                    Global.World.WorldRect.size.y / i < 16384):
                    logv("Found one! %d" % i)
                    self.config_defaults["render_scale"] = i

            Global.Editor.Warn(
                "Map Size Warning",
                """Render scale has been reduced to %s due to map size. 
                To avoid this, don't use map sizes greater than around 100""" % [
                    self.config_defaults["render_scale"]
                ]
            )

        self._setup_brush_settings()
        self._setup_export_settings()
        self._setup_memory_settings()
        self._setup_ui_settings()

    func _process(delta):
        self._update_estimates()

    func _exit_tree():
        self.queue_free()

    func _load_config():
        var dir = Directory.new()
        if not dir.dir_exists(CONFIG_FILE_DIR):
            dir.make_dir(CONFIG_FILE_DIR)
        self.config_file = File.new()
        self.config_file.open(CONFIG_FILE_PATH, File.READ)
        var file_content = self.config_file.get_as_text()
        var config = JSON.parse(file_content)
        if config.result is Dictionary:
            self.config_dict = config.result
            logi("Config Loaded")
            logv(JSON.print(config.result, "\t"))
        else:
            logi("Config was empty or invalid, ignoring config file")
        
        self.config_file.close()
        Global.World.set_meta("painter_config", self)

    func _save_config(force = false):
        logv("_save_config called")
        if not self.visible and not force:
            logv("UI not visible, ignoring save request")
            return

        
        self.config_file.open(CONFIG_FILE_PATH, File.WRITE)
        self._update_config_dict()
        
        self.config_file.store_string(JSON.print(
            self.config_dict,
            "\t"
        ))
        self.config_file.close()

    func _update_config_dict():
        for node in self.config_nodes:
            if not node.has_meta("config_key"):
                logv("Node %s had no associated config_key, ignoring" % node)
                continue
            
            var node_key = node.get_meta("config_key")
            var node_value
            logv("saving config for node %s (key: %s)" % [node, node_key])

            if node.Color != null: node_value = node.Color.to_html()
            elif node is Range: node_value = node.value
            elif node is OptionButton: node_value = node.selected
            elif node is CheckBox: node_value = node.pressed
            
            if node_value != null and self.config_defaults[node_key] != node_value:
                config_dict[node_key] = node_value
            elif node_value != null and self.config_defaults[node_key] == node_value:
                config_dict.erase(node_key)

        Global.World.set_meta("painter_config", self)


    # ===== UI SETUP =====
    func _setup_ui_settings():
        logv("Setting up UI settings UI")
        var cat_root = ($"Align/UISettings" as GridContainer)
        var config_val

        var user_layer_check = (cat_root.get_node("UseUserLayers") as CheckBox)
        user_layer_check.set_meta("config_key", "use_user_layers")
        config_val = self.get_c_val("use_user_layers")
        user_layer_check.pressed = config_val
        self.config_nodes.append(user_layer_check)


    func _setup_brush_settings():
        logv("Setting up brush settings UI")
        var cat_root = ($"Align/BrushSettings" as GridContainer)
        var config_val

        var default_color_button = ColorPalette.new(false)
        default_color_button.set_meta("config_key", "def_brush_col")
        default_color_button.AddPresets(Cache.DefaultCustomColors)
        cat_root.add_child(default_color_button)
        config_val = self.get_c_val("def_brush_col")
        default_color_button.Color = config_val
        logv("setup color_button")
        self.config_nodes.append(default_color_button)

        var default_brush_size = (cat_root.get_node("DefSizeVal") as SpinBox)
        default_brush_size.set_meta("config_key", "def_size_val")
        config_val = self.get_c_val("def_size_val")
        default_brush_size.value = config_val
        self.config_nodes.append(default_brush_size)
        logv("setup default_brush_size")

    func _setup_export_settings():
        logv("Setting up export settings UI")
        var cat_root = ($"Align/ExportSettings" as GridContainer)
        var config_val

        var default_export_format = (cat_root.get_node("FormatVal") as OptionButton)
        default_export_format.set_meta("config_key", "def_export_format")
        config_val = self.get_c_val("def_export_format")
        default_export_format.select(config_val)
        self.config_nodes.append(default_export_format)
        logv("set up def_export_format")

        var premult_alpha_export = (cat_root.get_node("PremultVal") as CheckBox)
        premult_alpha_export.set_meta("config_key", "export_premultiplied")
        config_val = self.get_c_val("export_premultiplied")
        premult_alpha_export.set_pressed_no_signal(config_val)
        self.config_nodes.append(premult_alpha_export)
        logv("set up export_premultiplied")

    func _setup_memory_settings():
        logv("Setting up memory settings UI")
        var cat_root = ($"Align/MemorySettings" as VBoxContainer)
        var config_val
        
        var num_undo_states = (cat_root.get_node("Undo/UndoStates") as SpinBox)
        num_undo_states.set_meta("config_key", "num_undo_states")
        config_val = self.get_c_val("num_undo_states")
        num_undo_states.value = config_val
        self.config_nodes.append(num_undo_states)
        logv("set up num_undo_states")

        var render_scale = (cat_root.get_node("Rendering/RenderScale") as SpinBox)
        render_scale.set_meta("config_key", "render_scale")
        config_val = self.get_c_val("render_scale")
        render_scale.value = config_val
        self.config_nodes.append(render_scale)
        logv("set up render_scale")

    func _update_estimates():
        var mem_root = ($"Align/MemorySettings" as VBoxContainer)
        var render_scale = $"Align/MemorySettings/Rendering/RenderScale".value
        var res_label = (mem_root.get_node("Rendering/EffectiveResolution") as Label)
        res_label.text = "%d x %d" % [
            Global.World.WorldRect.size.x / render_scale,
            Global.World.WorldRect.size.y / render_scale
        ]

        var mem_label = (mem_root.get_node("Rendering/MemPerLayer") as Label)
        mem_label.text = "%d MB" % self.get_memory_usage_per_layer()
        
        var undo_mem_label = (mem_root.get_node("Undo/UndoMemoryUsage") as Label)
        undo_mem_label.text = "%d MB" % (
            self.get_memory_usage_per_layer() * (self.get_c_val("num_undo_states") * 2)
        )

    # ===== UTIL =====
    ### get_memory_usage_per_layer()
    # Returns the size (in megabytes) a layer will be with the current settings
    func get_memory_usage_per_layer() -> int:
        var render_scale = $"Align/MemorySettings/Rendering/RenderScale".value
        var resolution = Global.World.WorldRect.size / Vector2(
            render_scale,
            render_scale
        )
        var memory_usage = ((8 * 4) * resolution.x) * resolution.y
        memory_usage = memory_usage / 8
        memory_usage = memory_usage / pow(10, 6)
        return memory_usage

    ### get_c_val
    # Attempts to retrieve key from config, returning default if it's not set,
    # and null if the key is unknown
    func get_c_val(key: String):
        if self.config_dict.get(key) != null: return self.config_dict[key]
        if self.config_defaults.get(key) != null: return self.config_defaults[key]
        else:
            logd("Invalid c_val key: %s" % key)
            return null

    # ===== SIGNAL HANDLERS =====
    func _on_default_color_changed(color: Color):
        self.config_dict["def_brush_col"] = color.to_html()
    
    func _on_default_format_changed(item_index: int):
        self.config_dict["default_format"] = ($"Align/ExportSettings/FormatVal" as OptionButton).get_item_text(item_index)

    func _on_renderscale_changed(val: int):
        pass
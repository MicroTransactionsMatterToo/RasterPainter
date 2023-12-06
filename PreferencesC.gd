class_name PreferencesC

var script_class = "tool"

const LOG_LEVEL = 4

class Preferences extends PanelContainer:
    var Global

    var layerm
    var scontrol
    var brushmgr

    var template

    var ColorPalette
    var Cache

    const CONFIG_FILE_PATH = "user://ShadowPainter/config.json"

    var config_dict := {}

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
    func _init(global, layerm, scontrol, brushmgr).():
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol
        self.brushmgr = brushmgr

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

    # ===== UI SETUP =====
    func _setup_brush_settings():
        var cat_root = ($"Align/BrushSettings" as VBoxContainer)

        var default_color_button = ColorPalette.new(false)
        default_color_button.AddPresets(Cache.DefaultCustomColors)
        cat_root.add_child(default_color_button)

    # ===== SIGNAL HANDLERS =====
    func _on_default_color_changed(color: Color):
        self.config_dict["def_color"] = color.to_html()
    
    func _on_default_format_changed(item_index: int):
        self.config_dict["default_format"] = ($"Align/ExportSettings/FormatVal" as OptionButton).get_item_text(item_index)

    func _on_renderscale_changed(val: int):
        pass
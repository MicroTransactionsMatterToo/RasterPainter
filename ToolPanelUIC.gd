class_name ToolPanelUIC

var script_class = "tool"


const LOG_LEVEL = 4


class RasterToolpanel extends VBoxContainer:
    var Global
    var template

    var scontrol
    var layerm
    var brushmgr

    var palette_control

    var brush_buttons := ButtonGroup.new()

    var ColorPalette

    enum HistoryOperation {
        UNDO,
        REDO
    }


    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <ToolPanelUI>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <ToolPanelUI>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <ToolPanelUI>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    # ===== BUILTINS =====

    func _init(global, layerm, scontrol, brushmgr).():
        logv("init called")
        self.Global = global

        self.layerm = layerm
        self.scontrol = scontrol
        self.brushmgr = brushmgr

        self.name = "RasterToolPanel"

        ColorPalette = load("res://scripts/ui/elements/ColorPalette.cs")

        logv("Loading UI template")
        self.template = ResourceLoader.load(Global.Root + "ui/toolpanel.tscn", "", true)
        var instance = template.instance()
        self.add_child(instance)
        instance.remove_and_skip()
        logv("Template loaded")

        self.size_flags_horizontal = SIZE_EXPAND_FILL
        self.size_flags_vertical = SIZE_EXPAND_FILL

        self.set_anchor_and_margin(0, 0, 0, false)

        logv("VBoxContainer configured")


        self.palette_control = ColorPalette.new(false)
        self.palette_control.SetColor(Color(0, 0, 0, 1), false)
        logv("ColorPalette instance created")
        var color_presets = [
            Color.red.to_html(),
            Color.green.to_html(),
            Color.blue.to_html()
        ]
        self.palette_control.AddPresets(color_presets)
        logv("ColorPalette presets set")
        self.palette_control.connect(
            "color_changed",
            self,
            "on_color_changed"
        )
        logv("color_changed connected")

        $"BrushControls/BrushSettings/BColorC".add_child(self.palette_control)
        $"BrushControls/BrushSettings/BSizeC/BSize/HSlider".connect(
            "value_changed",
            self,
            "on_size_changed"
        )
        $"BrushControls/BrushSettings/BSizeC/BSize/HSlider".share(
            $"BrushControls/BrushSettings/BSizeC/BSize/SpinBox"
        )
        logv("ColorPalette added to UI")

        $"LayerControls/HistoryB/Undo".icon = load("res://ui/icons/menu/undo.png")
        $"LayerControls/HistoryB/Redo".icon = load("res://ui/icons/menu/redo.png")

        self.populate_brushes()
        logv("Brushes populated")
        ($"BrushControls/BrushSettings/BSizeC/BSize/HSlider" as HSlider).value = self.brushmgr.size
        self.palette_control.Color = self.brushmgr.color


    func _ready():
        self.brush_buttons.connect(
            "pressed",
            self,
            "on_brush_button_pressed"
        )

        $"LayerControls/HistoryB/Undo".connect(
            "pressed",
            self,
            "on_undo_redo",
            [HistoryOperation.UNDO]
        )

        $"LayerControls/HistoryB/Redo".connect(
            "pressed",
            self,
            "on_undo_redo",
            [HistoryOperation.REDO]
        )

    func _process(delta):
        ($"LayerControls/HistoryB/Redo" as Button).disabled = self.scontrol.redo_queue.empty()
        ($"LayerControls/HistoryB/Undo" as Button).disabled = self.scontrol.history_queue.empty()
        self.brushmgr.current_brush = self.brush_buttons.get_pressed_button().get_meta("brush_name")

    func on_color_changed(color):
        logv("Color changed %s to %s" % [self.brushmgr.color, color])
        self.brushmgr.color = color

    func on_size_changed(size):
        logv("Size changed %d to %d" % [self.brushmgr.size, size])
        self.brushmgr.size = size

    func on_brush_button_pressed(button):
        logv("brush_button pressed: %s" % button)
        self.brushmgr.current_brush.hide_ui()
        self.brushmgr.current_brush = button.get_meta("brush_name")
        self.brushmgr.current_brush.on_selected()
        self.brushmgr.current_brush.show_ui()
        self.configure_ui(
            self.brushmgr.current_brush.ui_config()
        )

    ### set_palette
    # TODO: implement this properly
    func set_palette(palette_key: String):
        return null
        logv("setting palette to %s" % palette_key)
        var palette
        if Global.Editor.Toolset.ColorPalettes.has(palette_key):
            logv("existing palette found, loading")
            palette = Global.Editor.Toolset.ColorPalettes[palette_key].Save()
        else:
            logv("palette not defined, adding")
            palette = [
                Color.red,
                Color.green,
                Color.blue
            ]
            var new_palette = ColorPalette.new(false)
            new_palette.AddPresets(palette)
            Global.Editor.Toolset.ColorPalettes[palette_key] = new_palette
        
        logv("add palette")
        self.palette_control.colorList.AddPresets(palette)
            

    
    ### configure_ui
    # Takes a dictionary dictating how the shared brush UI should be configured
    # Mostly used to disable color selection for brushes where it doesn't apply
    func configure_ui(config: Dictionary):
        logv("Configuring brush_ui")
        for key in config.keys():
            match key:
                "size":
                    $"BrushControls/BrushSettings/BSizeC/BSize".visible = config[key]
                "color":
                    $"BrushControls/BrushSettings/BColorC".visible = config[key]
                "palette":
                    self.set_palette(config[key])
                _:
                    continue

    ### on_undo_redo
    # Called on undo or redo
    func on_undo_redo(operation: int):
        logv("on_undo_redo: %s" % operation)
        var operation_queue
        var append_queue
        match operation:
            HistoryOperation.REDO: 
                operation_queue = self.scontrol.redo_queue
                append_queue = self.scontrol.history_queue
            HistoryOperation.UNDO: 
                operation_queue = self.scontrol.history_queue
                append_queue = self.scontrol.redo_queue
            _: 
                logv("Invalid operation")
                return null

        if operation_queue.empty():
            logv("History Queue is empty, not undoing")
            return
        
        var uuid = operation_queue.last_uuid()
        if uuid == null:
            logv("Invalid history entry, ignoring")
            self.scontrol.history_queue.pop()
            return
        
        var layer = self.layerm.get_layer_by_uuid(uuid)
        if layer == null:
            logv("Layer that history item pointed to no longer exists, ignoring")
            operation_queue.pop()
            return

        var texture = operation_queue.pop()
        logv("history texture is %s, current texture is %s" % [texture, layer.texture])
        
        var current_texture = layer.texture.duplicate(false)
        current_texture.set_meta("layer_id", layer.uuid)
        append_queue.push(current_texture)

        
        layer.texture = texture
        self.scontrol.blending_rectangle.material.set_shader_param(
            "base_texture", 
            layer.texture
        )
        
    ### populate_brushes
    # Loads the UI for each brush in the `BrushManager`
    func populate_brushes():
        logv("Populating brushes from %s" % self.brushmgr._brushes)
        for brush in self.brushmgr._brushes.values():
            logv("Adding brush: %s" % brush)
            var brush_ui = brush.brush_ui()
            if brush_ui != null:
                $"BrushUI".add_child(brush_ui)
                logv("brush_ui added: %s" % brush_ui)
                brush.hide_ui()

            var brush_button = Button.new()
            brush_button.set_meta("brush_name", brush.brush_name)
            brush_button.icon = brush.icon
            brush_button.group = self.brush_buttons
            brush_button.toggle_mode = true

            $"BrushControls/BrushSelector".add_child(brush_button)
        
        self.brush_buttons.get_buttons()[0].set_pressed_no_signal(true)
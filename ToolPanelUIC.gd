class_name ToolPanelUIC

var script_class = "tool"


const LOG_LEVEL = 4


class ShadowToolpanel extends VBoxContainer:
    var Global
    var template

    var scontrol
    var layerm
    var brushmgr

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

        self.name = "ShadowToolPanel"

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


        var color_palette = ColorPalette.new(false)
        logv("ColorPalette instance created")
        var color_presets = [
            Color.red.to_html(),
            Color.green.to_html(),
            Color.blue.to_html()
        ]
        color_palette.AddPresets(color_presets)
        logv("ColorPalette presets set")
        color_palette.connect(
            "color_changed",
            self,
            "on_color_changed"
        )
        logv("color_changed connected")

        $"BrushControls/BrushSettings/BColorC".add_child(color_palette)
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
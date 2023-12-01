class_name ToolPanelUIC

var script_class = "tool"


const LOG_LEVEL = 4


class ShadowToolpanel extends HBoxContainer:
    var Global
    var template

    var scontrol
    var layerm
    var brushmgr

    var brush_buttons := ButtonGroup.new()

    var ColorPalette = load("res://scripts/ui/elements/ColorPalette.cs")

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("[V] <ToolPanelUI>: ")
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("[D] <ToolPanelUI>: ")
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("[I] <ToolPanelUI>: ")
            print(msg)
        else:
            pass

    # ===== BUILTINS =====

    func _init(global, layerm, scontrol, brushmgr).():
        self.Global = global

        self.layerm = layerm
        self.scontrol = scontrol
        self.brushmgr = brushmgr

        self.template = ResourceLoader.load(Global.Root + "ui/toolpanel.tscn", "", true)
        var instance = template.instance()
        self.add_child(instance)
        instance.remove_and_skip()

        self.size_flags_horizontal = SIZE_EXPAND_FILL
        self.size_flags_vertical = SIZE_EXPAND_FILL

        self.set_anchor_and_margin(0, 0, 0, false)

        var color_palette = ColorPalette.new(false)
        var color_presets = [
            Color.red.to_html(),
            Color.green.to_html(),
            Color.blue.to_html()
        ]
        color_palette.AddPresets(color_presets)
        color_palette.connect(
            "color_changed",
            self,
            "on_color_changed"
        )

        $"BrushControls/BrushSettings/BColorC".add_child(color_palette)
        $"BrushControls/BrushSettings/BSizeC/HSlider".connect(
            "value_changed",
            self,
            "on_size_changed"
        )

        self.populate_brushes()


    func _ready():
        self.brush_buttons.connect(
            "pressed",
            self,
            "on_brush_button_pressed"
        )

    func on_color_changed(color):
        self.brushmgr.color = color

    func on_size_changed(size):
        self.brushmgr.size = size

    func on_brush_button_pressed(button):
        self.brushmgr.current_brush.hide_ui()
        self.brushmgr.current_brush = button.get_meta("brush_name")
        self.brushmgr.current_brush.show_ui()

    func populate_brushes():
        for brush in self.brushmgr._brushes:
            $"BrushUI".add_child(brush.ui())
            brush.hide_ui()

            var brush_button = Button.new()
            brush_button.set_meta("brush_name", brush.brush_name)
            brush_button.icon = brush.icon
            brush_button.group = self.brush_buttons
            brush_button.toggle_mode = true

            $"BrushControls/BrushSelector".add_child(brush_button)

        self.brush_buttons.get_buttons()[0].set_pressed_no_signal(true)
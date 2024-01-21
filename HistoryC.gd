var script_class = "tool"

const LOG_LEVEL = 4

class HistoryManager:
    var Global
    var scontrol
    var layerm


    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <HistoryManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <HistoryManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <HistoryManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func _init(global, scontrol, layerm):
        logv("HistoryManager init")
        self.Global = global
        self.scontrol = scontrol
        self.layerm = layerm

    func record_paint(layer):
        if Global.API == null: return
        logv("record_paint for layer: %s" % [layer])
        logv("API: %s" % self.Global.API)
        var record = LayerPaintRecord.new(layer, self.scontrol)
        self.Global.API.HistoryApi.record(record)

    func record_layer_edit(old_key, layer):
        if Global.API == null: return
        logv("record_layer_edit with params: old_key = %s, layer = %s" % [old_key, layer])
        var record = LayerEditRecord.new(old_key, layer, self.scontrol)
        self.Global.API.HistoryApi.record(record)

    func record_layer_move(move_entries):
        if Global.API == null: return
        logv("record_layer_move with entries: %s" % [move_entries])
        var record = LayerMoveRecord.new(move_entries, self.scontrol)
        self.Global.API.HistoryApi.record(record)

    func record_layer_delete(layer):
        if Global.API == null: return
        logv("record_layer_delete called with layer: %s" % [layer])
        var record = LayerDeleteRecord.new(layer, self.scontrol)
        return record

    func record_bulk_layer_delete(records):
        if Global.API == null: return
        logv("record_bulk_layer_deletes called")
        var record = LayerDeleteRecords.new(records, self.scontrol)
        self.Global.API.HistoryApi.record(record)

    func record_layer_add(layer, params):
        if Global.API == null: return
        logv('record_layer_add called')
        var record = LayerAddRecord.new(layer, params, self.scontrol)
        self.Global.API.HistoryApi.record(record)
    
class RasterRecord:
    var MAGIC = "RRCRD"

## LayerPaintRecord
# Class that stores a brush stroke or modification to the contents of a RasterLayer
class LayerPaintRecord extends RasterRecord:
    var texture
    var uuid
    var scontrol

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <LayerPaintRecord>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <LayerPaintRecord>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <LayerPaintRecord>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func _init(layer, scontrol):
        logv("paint record init: %s" % layer)
        self.texture = layer.texture.duplicate(false)
        self.uuid = layer.uuid
        self.scontrol = scontrol

    func undo() -> bool:
        var layer = self.scontrol.layerm.get_layer_by_uuid(self.uuid)
        if layer == null or not is_instance_valid(layer):
            return false

        var new_texture = layer.texture.duplicate(false)
        layer.texture = self.texture
        self.scontrol.blending_rectangle.material.set_shader_param(
            "base_texture",
            self.scontrol.active_layer.texture
        )
        layer.force_update_tex()

        self.texture = new_texture
        
        return true

    func redo() -> bool:
        return self.undo()

    func max_count() -> int:
        var prefs = self.scontrol.Global.World.get_meta("painter_config")
        if prefs == null:
            return 10
        else:
            return prefs.get_c_val("num_undo_states")

    func record_type() -> String:
        return "LayerPaintRecord"

class LayerEditRecord extends RasterRecord:
    var scontrol

    var uuid
    var undo_diff = {}
    var redo_diff = {} 

    var invalid_record = false
    
    func _init(old_key, layer, scontrol):
        self.uuid = layer.uuid
        self.scontrol = scontrol

        var old_key_data = layer.decode_key(old_key)
        var new_key_data = layer.decode_key(layer.embedded_key)


        if old_key_data["uuid"] != new_key_data["uuid"]:
            print("ERROR: Attempt to create LayerEditRecords with layers of differing UUID")
            self.invalid_record = true
            return

        for key in new_key_data.keys():
            if old_key_data[key] != new_key_data[key]:
                self.undo_diff[key] = old_key_data[key]
        
        for key in old_key_data.keys():
            if new_key_data[key] != old_key_data[key]:
                self.redo_diff[key] = new_key_data[key]

    
    func apply_diff(diff) -> bool:
        if invalid_record: return false
        
        var layer = self.scontrol.layerm.get_layer_by_uuid(self.uuid)
        if layer == null or not is_instance_valid(layer):
            return false

        for key in diff.keys():
            match key:
                "level_id": layer.set_level_id(diff[key])
                "layer_name": layer.set_layer_name(diff[key])
                "modulate": layer.set_modulate(diff[key])
                "_": pass
            
        return true
    
    func undo() -> bool:
        return self.apply_diff(undo_diff)

    func redo() -> bool:
        return self.apply_diff(redo_diff)

    func record_type():
        return "LayerEditRecord"

class LayerMoveRecord extends RasterRecord:
    ### move_entries
    # Array of objects structured as such
    # [
    #   [uuid, old_z, new_z]
    # ]
    var move_entries
    var scontrol
    var layerm

    enum {
        UUID = 0,
        OLD_Z,
        NEW_Z
    }

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <LayerMoveRecord>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <LayerMoveRecord>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <LayerMoveRecord>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func _init(move_entries, scontrol):
        logv("LayerMoveRecord init, entries: %s" % [move_entries])
        self.move_entries = move_entries
        self.scontrol = scontrol
        self.layerm = scontrol.layerm

    func undo() -> bool:
        for entry in self.move_entries:
            var entry_layer = self.layerm.get_layer_by_uuid(entry[UUID])
            if entry_layer != null and is_instance_valid(entry_layer):
                entry_layer.set_z_index(entry[OLD_Z])

        return true

    func redo() -> bool:
        for entry in self.move_entries:
            var entry_layer = self.layerm.get_layer_by_uuid(entry[UUID])
            if entry_layer != null and is_instance_valid(entry_layer):
                entry_layer.set_z_index(entry[NEW_Z])

        return true


class LayerDeleteRecords extends RasterRecord:
    var records
    var scontrol

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <LayerDeleteRecords>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <LayerDeleteRecords>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <LayerDeleteRecords>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    

    func _init(records, scontrol):
        self.records = records
        self.scontrol = scontrol

    func redo() -> bool:
        logv("bulk delete redo")
        for record in self.records:
            record.redo()
        
        return true

    func undo() -> bool:
        logv("bulk delete undo")
        for record in self.records:
            record.undo()

        return true

    func dropped(type):
        for record in self.records:
            record.dropped(type)

    func max_count() -> int: return 10


class LayerDeleteRecord extends RasterRecord:
    var Global

    var texture
    var old_key
    var layer_uuid
    var layer_params
    var scontrol
    
    var RasterLayerC
    var RasterLayer

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <LayerDeleteRecord>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <LayerDeleteRecord>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <LayerDeleteRecord>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    

    func _init(layer, scontrol):
        self.old_key = layer.embedded_key
        self.layer_uuid = layer.uuid
        self.texture = layer.texture.duplicate(false)
        self.scontrol = scontrol
        self.Global = scontrol.Global

        RasterLayerC    = ResourceLoader.load(Global.Root + "RasterLayerC.gd", "GDScript", true)
        RasterLayer     = load(Global.Root + "RasterLayerC.gd").RasterLayer

    func undo() -> bool:
        logv("managed_layers: %s" % JSON.print(self.scontrol.layerm.loaded_layers, "\t"))
        Global.World.EmbeddedTextures[self.old_key] = self.texture
        logv("set global texture to %s" % [self.texture])

        var new_layer = RasterLayer.new(Global)
        logv("created new layer")
        new_layer.create_from_key(
            self.old_key
        )
        logv("instantianted it using old key: %s" % self.old_key)

        
        logv("idled")
        self.scontrol.layerm.add_layer(new_layer)
        logv("managed_layers: %s" % JSON.print(self.scontrol.layerm.loaded_layers, "\t"))
        logv("added layer: %s" % new_layer)

        self.scontrol.set_active_layer(new_layer)
        self.scontrol.layerui.layer_tree.populate_tree(self.scontrol.curr_level_id)

        return true
    
    func redo() -> bool:
        var layer = self.scontrol.layerm.get_layer_by_uuid(self.layer_uuid)

        self.scontrol.layerm.remove_layer(layer)
        layer.delete()

        yield(self.scontrol.get_tree(), "idle_frame")
        self.scontrol.layerui.layer_tree.populate_tree(self.scontrol.curr_level_id)
        
        return true

    func max_count() -> int: return 10

    func record_type() -> String:
        return "LayerPaintRecord"

class LayerAddRecord extends RasterRecord:
    var Global

    var added_uuid
    var layer_params
    var scontrol

    var RasterLayerC
    var RasterLayer

    func _init(layer, layer_params, scontrol):
        self.added_uuid = layer.uuid
        self.layer_params = layer_params
        self.scontrol = scontrol
        self.Global = scontrol.Global

        RasterLayerC    = ResourceLoader.load(Global.Root + "RasterLayerC.gd", "GDScript", true)
        RasterLayer     = load(Global.Root + "RasterLayerC.gd").RasterLayer

    func undo() -> bool:
        print("undoing layer add")
        var layer = self.scontrol.layerm.get_layer_by_uuid(self.added_uuid)
        self.scontrol.layerm.remove_layer(layer)
        layer.delete()

        yield(self.scontrol.get_tree(), "idle_frame")
        self.scontrol.layerui.layer_tree.populate_tree(self.scontrol.curr_level_id)

        return true

    func redo() -> bool:
        var new_layer = RasterLayer.new(Global)
        new_layer.create_new(
            layer_params["level_id"],
            layer_params["z_index"],
            layer_params["name"],
            self.added_uuid
        )

        new_layer.set_z_index(new_layer.z_index)
        self.scontrol.layerm.add_layer(new_layer)
        self.scontrol.set_active_layer(new_layer)

        self.scontrol.layerui.layer_tree.populate_tree(self.scontrol.curr_level_id)

        return true
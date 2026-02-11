extends HBoxContainer

@export var floppy: Control

func _enter_tree() -> void:
    floppy.hide()
    if __SignalBus.on_pickup_tool_key.connect(_handle_pickup_tool_key) != OK:
        push_error("Failed to connect pickup tool key")
    if __SignalBus.on_deposited_tool_key.connect(_handle_key_deposited) != OK:
        push_error("Failed to connect deposited tool key")

func _handle_pickup_tool_key(key: ToolKey.KeyVariant) -> void:
    match key:
        ToolKey.KeyVariant.FLOPPY_KEY:
            floppy.show()

func _handle_key_deposited(_total: int, key: ToolKey.KeyVariant) -> void:
    match key:
        ToolKey.KeyVariant.FLOPPY_KEY:
            floppy.hide()

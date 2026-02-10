extends Tool
class_name ToolKey

enum KeyVariant { NONE, FLOPPY_KEY}
@export var _variant: KeyVariant = KeyVariant.NONE

func _ready() -> void:
    if _type == ToolType.KEY && _variant != KeyVariant.NONE:
        if __GlobalGameState.collected_keys.has(_variant):
            queue_free()

func _do_pickup() -> void:
    if _type == ToolType.KEY && _variant != KeyVariant.NONE:
        __SignalBus.on_pickup_tool_key.emit(_variant)

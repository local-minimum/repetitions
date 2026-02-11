extends PanelContainer

func _enter_tree() -> void:
    if __SignalBus.on_deposited_tool_key.connect(_handle_deposit_key) != OK:
        push_error("Failed to connect deposit tool key")

func _ready() -> void:
    hide()

func _handle_deposit_key(total: int, _key: ToolKey.KeyVariant) -> void:
    if total > 0:
        show()


func _on_ok_pressed() -> void:
    hide()

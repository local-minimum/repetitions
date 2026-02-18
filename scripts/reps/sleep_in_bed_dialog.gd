extends PanelContainer

func _enter_tree() -> void:
    if __SignalBus.on_request_rest.connect(_handle_request_rest) != OK:
        push_error("Failed to request rest")

func _ready() -> void:
    hide()

func _handle_request_rest(_bed: Node3D, _coords: Vector3i) -> void:
    __GlobalGameState.game_paused = true
    show()

func _on_cancel_btn_pressed() -> void:
    __GlobalGameState.game_paused = false
    hide()

func _on_accept_btn_pressed() -> void:
    __GlobalGameState.go_to_next_day()

extends PanelContainer

func _enter_tree() -> void:
    if __SignalBus.on_demo_end.connect(show, CONNECT_ONE_SHOT) != OK:
        push_error("Failed to connect demo end")

func _ready() -> void:
    hide()

func _on_ok_pressed() -> void:
    get_tree().quit()

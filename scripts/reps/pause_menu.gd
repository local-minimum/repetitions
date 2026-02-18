extends PanelContainer

func _ready() -> void:
    hide()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"crawl_pause"):
        _toggle_menu_active()
        get_viewport().set_input_as_handled()

func _toggle_menu_active() -> void:
    if visible:
        __GlobalGameState.game_paused = false
        hide()
    else:
        __GlobalGameState.game_paused = true
        show()

func _on_resume_pressed() -> void:
    __GlobalGameState.game_paused = false
    hide()

func _on_next_day_pressed() -> void:
    hide()
    __GlobalGameState.go_to_next_day()

func _on_quit_pressed() -> void:
    get_tree().quit()

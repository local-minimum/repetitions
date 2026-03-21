@tool
extends EditorPlugin

func _enter_tree() -> void:
    pass


func _exit_tree() -> void:
    pass

## Activation & Editor Setup
func _enable_plugin() -> void:
    add_free_cam_bindings()

func _create_key_events(keys: Array[Key]) -> Array[InputEvent]:
    var evts: Array[InputEvent]
    for key: Key in keys:
        var evt: InputEventKey = InputEventKey.new()
        evt.keycode = key
        evts.append(evt)

    return evts

func _add_joy_events(events: Array[InputEvent], keys: Array[JoyButton]) -> void:
    var input_controller: InputEventJoypadButton = InputEventJoypadButton.new()
    input_controller.button_index = JOY_BUTTON_A
    events.append(input_controller)

func add_free_cam_bindings() -> void:
    var updated: bool
    var key: String = "input/toggle_free_look_cam_keyb"
    if !ProjectSettings.has_setting(key):
        updated = true
        ProjectSettings.set_setting(
            key,
            {"deadzone": 0.5, "events": _create_key_events([KEY_CTRL])},
        )

    key = "input/toggle_free_look_cam_mouse"
    if !ProjectSettings.has_setting(key):
        updated = true
        var input_right_click: InputEventMouseButton = InputEventMouseButton.new()
        input_right_click.button_index = MOUSE_BUTTON_RIGHT
        input_right_click.pressed = true
        input_right_click.device = -1
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": [input_right_click]})

    key = "input/crawl_forward"
    if !ProjectSettings.has_setting(key):
        updated = true
        var events: Array[InputEvent] = _create_key_events([KEY_W, KEY_UP, KEY_KP_8])
        _add_joy_events(events, [JOY_BUTTON_DPAD_UP])
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events})

    key = "input/crawl_backward"
    if !ProjectSettings.has_setting(key):
        updated = true
        var events: Array[InputEvent] = _create_key_events([KEY_S, KEY_DOWN, KEY_KP_5, KEY_KP_2])
        _add_joy_events(events, [JOY_BUTTON_DPAD_DOWN])
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events})

    key = "input/crawl_strafe_left"
    if !ProjectSettings.has_setting(key):
        updated = true
        var events: Array[InputEvent] = _create_key_events([KEY_A, KEY_LEFT, KEY_KP_4])
        _add_joy_events(events, [JOY_BUTTON_DPAD_LEFT])
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events},)

    key = "input/crawl_strafe_right"
    if !ProjectSettings.has_setting(key):
        updated = true
        var events: Array[InputEvent] = _create_key_events([KEY_D, KEY_RIGHT, KEY_KP_4])
        _add_joy_events(events, [JOY_BUTTON_DPAD_RIGHT])
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events})

    key = "input/crawl_turn_left"
    if !ProjectSettings.has_setting(key):
        updated = true
        var events: Array[InputEvent] = _create_key_events([KEY_Q, KEY_DELETE, KEY_KP_7])
        _add_joy_events(events, [JOY_BUTTON_LEFT_SHOULDER])
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events})

    key = "input/crawl_turn_right"
    if !ProjectSettings.has_setting(key):
        updated = true
        var events: Array[InputEvent] = _create_key_events([KEY_E, KEY_PAGEDOWN, KEY_KP_9])
        _add_joy_events(events, [JOY_BUTTON_RIGHT_SHOULDER])
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events})

    key = "input/crawl_search"
    if !ProjectSettings.has_setting(key):
        updated = true
        var events: Array[InputEvent] = _create_key_events([KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_F])
        _add_joy_events(events, [JOY_BUTTON_A])
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events})

    key = "input/hot_key_1"
    if !ProjectSettings.has_setting(key):
        updated = true
        var events: Array[InputEvent] = _create_key_events([KEY_1])
        _add_joy_events(events, [JOY_BUTTON_X])
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events})

    key = "input/hot_key_2"
    if !ProjectSettings.has_setting(key):
        updated = true
        var events: Array[InputEvent] = _create_key_events([KEY_2])
        _add_joy_events(events, [JOY_BUTTON_B])
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events})

    key = "input/hot_key_3"
    if !ProjectSettings.has_setting(key):
        updated = true
        var events: Array[InputEvent] = _create_key_events([KEY_3])
        _add_joy_events(events, [JOY_BUTTON_Y])
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events})

    key = "input/crawl_pause"
    if !ProjectSettings.has_setting(key):
        updated = true
        var events: Array[InputEvent] = _create_key_events([KEY_PAUSE, KEY_P])
        _add_joy_events(events, [JOY_BUTTON_START])
        ProjectSettings.set_setting(key, {"deadzone": 0.5, "events": events})
    #var input_controller: InputEventJoypadButton = InputEventJoypadButton.new()
    #input_controller.button_index = JOY_BUTTON_A

    if updated:
        ProjectSettings.save()

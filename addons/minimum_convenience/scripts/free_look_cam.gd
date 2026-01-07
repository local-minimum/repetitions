extends Node3D
class_name FreeLookCam

enum ToggleCause { MOVEMENT, KEYBOARD_ACTIVATOR, MOUSE_ACTIVATOR }

@export var _yaw_limit_degrees: float = 90
@export var _pitch_limit_degrees: float = 80
@export var _easeback_duration: float = 0.5
@export_category("Keyboard")
@export var keyboard_sensitivity: float = 60
@export var _keyboard_activation_toggle: String = "toggle_free_look_cam_keyb"
@export var _keyboard_up: String = "crawl_forward"
@export var _keyboard_down: String = "crawl_backward"
@export var _keyboard_left: String = "crawl_strafe_left"
@export var _keyboard_right: String = "crawl_strafe_right"
@export_category("Mouse")
@export var mouse_sensitivity_factor: float = 0.3
@export var _mouse_activation_toggle: String = "toggle_free_look_cam_mouse"

var _mouse_offset: Vector2 = Vector2.ZERO
var _keyboard_direction: Vector2 = Vector2.ZERO
var _total_yaw: float = 0
var _total_pitch: float = 0
var _easeback_tween: Tween
var _allow: bool = true
var _looking: bool:
    set(value):
        _looking = value
        if value:
            _keyboard_direction = Vector2.ZERO
            _mouse_offset = Vector2.ZERO
        if !value && (_total_pitch != 0 || _total_yaw != 0):
            _easeback()

func _enter_tree() -> void:
    if __SignalBus.on_toggle_freelook_camera.connect(_handle_toggle_freelook_camera) != OK:
        push_error("Cannot connect to toggle freelook camera")
    if __SignalBus.on_level_pause.connect(_handle_level_pause) != OK:
        push_error("Cannot connect to level pause")

func _handle_level_pause(_level: GridLevelCore, paused: bool) -> void:
    if _looking && !paused:
        _looking = false
    elif _looking && paused:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    _allow = !paused

func _handle_toggle_freelook_camera(active: bool, _cause: ToggleCause) -> void:
    if active != _looking:
        _looking = active

    if active:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    else:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _check_toggle(event: InputEvent, action: String, cause: ToggleCause) -> void:
    if event.is_action_pressed(action):
        _looking = true
        __SignalBus.on_toggle_freelook_camera.emit(_looking, cause)
    elif event.is_action_released(action):
        _looking = false
        __SignalBus.on_toggle_freelook_camera.emit(_looking, cause)

func _input(event: InputEvent) -> void:
    if !_allow:
        return

    _check_toggle(event, _mouse_activation_toggle, ToggleCause.MOUSE_ACTIVATOR)
    _check_toggle(event, _keyboard_activation_toggle, ToggleCause.KEYBOARD_ACTIVATOR)

    if !_looking:
        return

    if event is InputEventMouseMotion:
        _mouse_offset = (event as InputEventMouseMotion).relative
        return


    if event.is_action_pressed(_keyboard_up):
        _keyboard_direction.y -= 1.0
    elif event.is_action_released(_keyboard_up):
        _keyboard_direction.y += 1.0

    if event.is_action_pressed(_keyboard_down):
        _keyboard_direction.y += 1.0
    elif event.is_action_released(_keyboard_down):
        _keyboard_direction.y -= 1.0

    if event.is_action_pressed(_keyboard_left):
        _keyboard_direction.x -= 1.0
    elif event.is_action_released(_keyboard_left):
        _keyboard_direction.x += 1.0

    if event.is_action_pressed(_keyboard_right):
        _keyboard_direction.x += 1.0
    elif event.is_action_released(_keyboard_right):
        _keyboard_direction.x -= 1.0

func _easeback() -> void:
    if _easeback_tween != null && _easeback_tween.is_running():
        return

    _easeback_tween = create_tween()

    @warning_ignore_start("return_value_discarded")
    _easeback_tween.tween_method(
        _set_rotation,
        Vector2(_total_yaw, _total_pitch),
        Vector2.ZERO,
        _easeback_duration,
    )
    @warning_ignore_restore("return_value_discarded")

func _process(delta: float) -> void:
    if !_looking:
        return

    if _mouse_offset != Vector2.ZERO:
        _mouse_offset *= mouse_sensitivity_factor * AccessibilitySettings.mouse_sensitivity

        _set_rotation(Vector2(
            _total_yaw + _mouse_offset.x,
            _total_pitch + _mouse_offset.y
        ))

        _mouse_offset = Vector2.ZERO

    elif _keyboard_direction != Vector2.ZERO:
        var offset: Vector2 = _keyboard_direction * keyboard_sensitivity * delta

        _set_rotation(Vector2(
            _total_yaw + offset.x,
            _total_pitch + offset.y
        ))


func _set_rotation(orientation: Vector2) -> void:
    _total_yaw = clampf(orientation.x, -_yaw_limit_degrees, _yaw_limit_degrees)
    _total_pitch = clampf(orientation.y, -_pitch_limit_degrees, _pitch_limit_degrees)

    basis = Basis()
    rotate_object_local(Vector3.UP, deg_to_rad(-_total_yaw))
    rotate_object_local(Vector3.LEFT, deg_to_rad(-_total_pitch if AccessibilitySettings.mouse_inverted_y else _total_pitch))

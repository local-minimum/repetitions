extends CanvasLayer

@export var _player: PhysicsGridPlayerController
@export var _cinematic_btn: Button
@export var _gridless_btn: Button
@export var _debug_shapes_btn: Button

func _ready() -> void:
    _sync_cinematic.call_deferred()
    _sync_gridless.call_deferred()
    _sync_debug_shapes.call_deferred()

func _input(event: InputEvent) -> void:
    if event is InputEventKey && !event.is_echo():
        var e_key: InputEventKey = event
        if e_key.is_pressed() && e_key.keycode == KEY_ESCAPE:
            _player.gridless = false
            _sync_gridless()

func _sync_cinematic() -> void:
    _cinematic_btn.button_pressed = _player.cinematic

func _sync_gridless() -> void:
    _gridless_btn.button_pressed = _player.gridless

func _sync_debug_shapes() -> void:
    _debug_shapes_btn.button_pressed = _player._show_debug_shapes

func _on_cinematic_btn_pressed() -> void:
    _player.cinematic = !_player.cinematic
    _sync_cinematic()

func _on_gridless_btn_pressed() -> void:
    _player.gridless = !_player.gridless
    _sync_gridless()

func _on_debug_shapes_btn_pressed() -> void:
    _player._show_debug_shapes = !_player._show_debug_shapes
    _sync_debug_shapes()


func _on_reset_pos_btn_pressed() -> void:
    _player.global_position = _player.builder.get_closest_global_grid_position(Vector3.ZERO)

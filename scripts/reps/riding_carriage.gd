extends Node
class_name RidingCarriage

@export var _cart: TrackCarriage
@export var _interaction_body: InteractionBody3D
@export var _riding_position: Node3D
@export var _camera_view_position: Vector3


func _enter_tree() -> void:
    if _interaction_body.execute_interaction.connect(_handle_interaction) != OK:
        push_error("Failed to connect execute interaction")

    set_process_input(false)
    set_process(false)

var _riding: bool = false
var player: PhysicsGridPlayerController
var _tween: Tween

func _handle_interaction() -> void:
    if _riding:
        return

    player = PhysicsGridPlayerController.last_connected_player
    if player == null || player.cinematic:
        return

    set_process_unhandled_input(true)
    set_process(true)

    player.add_cinematic_blocker(self)
    _riding = true
    _tween = create_tween()

    var origin: Vector3 = player.global_position

    var _translation: Callable = func (progress: float) -> void:
        player.global_position = origin.lerp(_riding_position.global_position, progress)

    var _start_quart: Quaternion = player.global_basis.get_rotation_quaternion()

    var _orientation: Callable = func (progres: float) -> void:
        var q: Quaternion = lerp(
            _start_quart,
            _riding_position.global_basis.get_rotation_quaternion(),
            progres
        )
        player.global_rotation = q.get_euler()

    @warning_ignore_start("return_value_discarded")
    _tween.tween_method(_translation, 0.0, 1.0, 0.5)
    _tween.parallel().tween_interval(0.4)
    _tween.tween_method(_orientation, 0.0, 1.0, 0.3)
    _tween.parallel().tween_property(player.camera, "position", _camera_view_position, 0.4)
    _tween.parallel().tween_property(player.camera, "near", 0.05, 0.3)
    @warning_ignore_restore("return_value_discarded")

    if _tween.finished.connect(_start_train) != OK:
        push_error("Failed to connect to getting on train tween finished")
        await get_tree().create_timer(1.0).timeout
        _start_train()

func _start_train() -> void:
    __SignalBus.on_request_train_start.emit(_cart)

func _unhandled_input(event: InputEvent) -> void:
    if (
        event.is_action_pressed(&"crawl_forward") ||
        event.is_action_pressed(&"crawl_strafe_left") ||
        event.is_action_pressed(&"crawl_strafe_right") ||
        event.is_action_pressed(&"crawl_backward")
    ):
        if _tween != null && _tween.is_running():
            _tween.kill()

        _riding = false

        player.restore_camera_position()
        player.remove_cinematic_blocker(self)
        player.resume_control()

        player = null

        __SignalBus.on_request_train_stop.emit(_cart)

        set_process_unhandled_input(false)
        set_process(false)


func _process(_delta: float) -> void:
    if player == null || !_riding || (_tween != null && _tween.is_running()):
        return

    player.global_position = _riding_position.global_position
    player.global_rotation = _riding_position.global_rotation

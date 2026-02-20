extends Node
class_name GriddedController

@export var _player: PhysicsGridPlayerController

@export_range(0, 1) var _translation_duration: float = 0.3
@export_range(0, 1) var _rotation_duration: float = 0.25

@export_range(0, 1) var _refuse_distance_forward: float = 0.2
@export_range(0, 1) var _refuse_distance_other: float = 0.1

@export var _fudge_distance: float = 0.25

@export var _allow_vertical_movement: bool

var cam_offset: Vector3
var cam_near: float
var cam_fov: float

var _translation_tween: Tween
var _rotation_tween: Tween

func _ready() -> void:
    cam_offset = _player.camera.position

    cam_fov = _player.camera.fov
    cam_near = _player.camera.near

func handle_movement(translation_stack: Array[Movement.MovementType]) -> void:
    if !translation_stack.is_empty():
        var movement: Movement.MovementType = translation_stack[0]
        match movement:
            Movement.MovementType.FORWARD:
                _attempt_gridded_translation(movement, -_player.global_basis.z)
            Movement.MovementType.STRAFE_LEFT:
                _attempt_gridded_translation(movement, -_player.global_basis.x)
            Movement.MovementType.STRAFE_RIGHT:
                _attempt_gridded_translation(movement, _player.global_basis.x)
            Movement.MovementType.BACK:
                _attempt_gridded_translation(movement, _player.global_basis.z)
            _:
                push_error("Player %s's movement %s is not a valid translation" % [name, Movement.name(movement)])

    if Input.is_action_just_pressed("crawl_turn_left"):
        _attempt_turn(PI * 0.5)
    elif Input.is_action_just_pressed("crawl_turn_right"):
        _attempt_turn(-PI * 0.5)

## Force alignment with the grid
func transition_into_gridded() -> void:
    # NOTE: move needs to happend before turn
    _attempt_transition_to_gridded_translation()
    _attempt_turn(0.0)

func _calculate_estimated_gridded_translation_target(
    movement: Movement.MovementType = Movement.MovementType.NONE,
    direction: Vector3 = Vector3.ZERO,
) -> Vector3:
    return(
        _player.builder.get_closest_global_neighbour_position(_player.global_position, CardinalDirections.vector_to_direction(direction))
        if movement != Movement.MovementType.NONE else
        _player.builder.get_closest_global_grid_position(_player.global_position)
    )

func _normalize_gridded_translation_direction(movement: Movement.MovementType, direction: Vector3) -> Vector3:
    if !_allow_vertical_movement && direction.y != 0.0:
        print_debug("Removing y component of %s" % [direction])
        direction.y = 0

    if direction.length_squared() != 1.0:
        print_debug("Direction %s needs normalization" % [direction])
        if Movement.is_cardinal_translation(movement):
            direction = VectorUtils.primary_directionf(direction)
        else:
            direction = direction.normalized()
        print_debug("Normalized direction %s " % [direction])

    return direction

const _FLATNESS_THRESHOLD: float = 0.1 * PI

func _test_step(
    step_data:  Dictionary[PhysicsControllerStepCaster.StepData, Vector3],
    planar_delta: Vector3,
    fudge: float = 0.0
) -> bool:
    if _player.stepper.can_step(step_data, true):
        if step_data[PhysicsControllerStepCaster.StepData.NORMAL].angle_to(Vector3.UP) > _player.floor_max_angle:
            if fudge > 0.0:
                _player.caster_origin.global_position -= planar_delta.normalized() * fudge
                if _test_step(step_data, planar_delta, 0.0):
                    return true
            print_debug("Failed step from %s at %s due to angle %s, player at %s" % [
                _player.caster_origin.global_position,
                step_data,
                step_data[PhysicsControllerStepCaster.StepData.NORMAL].angle_to(Vector3.UP),
                _player.global_position
            ])
            return false


        _player.caster_origin.global_position.y = step_data[PhysicsControllerStepCaster.StepData.CENTER_POINT].y
    else:
        if fudge > 0.0:
            _player.caster_origin.global_position -= planar_delta.normalized() * fudge
            # Attempt lenient position but no iterative fudging
            return _test_step(step_data, planar_delta, 0.0)

        print_debug("Failed step from %s, player at %s" % [_player.caster_origin.global_position, _player.global_position])
        return false

    return true

func _attempt_gridded_translation(movement: Movement.MovementType, direction: Vector3, resolution: int = 6) -> void:
    if _translation_tween && _translation_tween.is_running() || _rotation_tween && _rotation_tween.is_running():
        return

    direction = _normalize_gridded_translation_direction(movement, direction)
    var target: Vector3 = _calculate_estimated_gridded_translation_target(movement, direction)
    direction = target - _player.global_position
    # Make direction planar, we'll deal with slopes later on
    direction.y = 0

    var planar_delta: Vector3 = Vector3(direction)
    direction = direction.normalized()

    print_debug("Attempting %s -> %s" % [_player.global_position, target])
    var steps: Array = [
        {
            PhysicsControllerStepCaster.StepData.POINT: _player.global_position,
            PhysicsControllerStepCaster.StepData.CENTER_POINT: _player.global_position,
            PhysicsControllerStepCaster.StepData.NORMAL: Vector3.UP,
        }
    ]

    _player.reset_caster_origin()

    var y: float = _player.global_position.y
    var failed: bool = false
    var fudge: float = minf(_fudge_distance, (0.8 * planar_delta / float(resolution)).length())
    for idx: int in resolution:
        var step_data:  Dictionary[PhysicsControllerStepCaster.StepData, Vector3]
        _player.caster_origin.global_position = _player.global_position + planar_delta * float(idx + 1) / float(resolution)
        _player.caster_origin.global_position.y = y
        if _test_step(step_data, planar_delta, fudge if idx == resolution - 1 else 0.0):
            steps.append(step_data)
            y = _player.caster_origin.global_position.y
        else:
            failed = true
            break

    _player.reset_caster_origin()

    if failed:
        if steps.size() < 2:
            target = steps[-1][PhysicsControllerStepCaster.StepData.CENTER_POINT]
        var mid: Vector3 = _player.global_position.lerp(target, _refuse_distance_forward if movement == Movement.MovementType.FORWARD else _refuse_distance_other)
        _animate_refused_movement(movement, mid)
        return

    var part_duration: float = _translation_duration / (steps.size() - 1)
    _translation_tween = create_tween()
    var prev_norm: Vector3 = Vector3.UP
    var prev_pt: Vector3 = _player.global_position

    @warning_ignore_start("return_value_discarded")
    print_debug(steps)
    for step: Dictionary in steps:
        var pt: Vector3 = step[PhysicsControllerStepCaster.StepData.CENTER_POINT]
        var norm: Vector3 = step[PhysicsControllerStepCaster.StepData.NORMAL]
        if (
            absf(pt.y - prev_pt.y) < _player.stepper.ignore_step_height ||
            norm.angle_to(Vector3.UP) > _FLATNESS_THRESHOLD ||
            prev_norm.angle_to(Vector3.UP) > _FLATNESS_THRESHOLD
        ):
            # Flat or slope walk
            _translation_tween.tween_property(
                _player,
                "global_position",
                pt,
                part_duration,
            )
        else:
            # We need stairs animation type
            _translation_tween.tween_property(
                _player,
                "global_position:x",
                pt.x,
                part_duration,
            )
            _translation_tween.set_parallel()
            _translation_tween.tween_property(
                _player,
                "global_position:z",
                pt.z,
                part_duration,
            )
            _translation_tween.tween_property(
                _player,
                "global_position:y",
                pt.y,
                part_duration,
            ).set_ease(Tween.EASE_OUT if prev_pt.y < pt.y else Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
            _translation_tween.set_parallel(false)

    @warning_ignore_restore("return_value_discarded")
    if _translation_tween.finished.connect(_player.handle_translation_end.bind(movement)) != OK:
        push_warning("Failed to connect end of movement")
        _player.handle_translation_end(movement)

func _attempt_transition_to_gridded_translation() -> void:
    if _translation_tween && _translation_tween.is_running() || _rotation_tween && _rotation_tween.is_running():
        return

    var target: Vector3 = _calculate_estimated_gridded_translation_target()

    _translation_tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    _translation_tween.tween_property(_player, "global_position", target, _translation_duration)
    @warning_ignore_restore("return_value_discarded")
    if _translation_tween.finished.connect(_player.handle_translation_end.bind(Movement.MovementType.CENTER)) != OK:
        push_warning("Failed to connect end of movement")
        _player.handle_translation_end(Movement.MovementType.CENTER)


func _attempt_turn(angle: float) -> void:
    if  _rotation_tween && _rotation_tween.is_running():
        return

    var t: Transform3D = _player.global_transform.rotated(Vector3.UP, angle)
    var target_global_rotation: Quaternion = _player.builder.get_cardial_rotation(t.basis.get_rotation_quaternion())

    _rotation_tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    var tween_func: Callable = QuaternionUtils.create_tween_rotation_method(_player)
    _rotation_tween.tween_method(tween_func, _player.global_transform.basis.get_rotation_quaternion(), target_global_rotation, _rotation_duration)
    @warning_ignore_restore("return_value_discarded")

func _animate_refused_movement(movement: Movement.MovementType, mid: Vector3) -> void:
    _translation_tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    _translation_tween.tween_property(_player, "global_position", mid, _translation_duration * 0.5)
    _translation_tween.tween_property(_player, "global_position", _player.global_position, _translation_duration * 0.5)
    @warning_ignore_restore("return_value_discarded")

    if _translation_tween.finished.connect(_player.handle_translation_end.bind(movement)) != OK:
        push_error("Failed to connect to translation tween end")
        _player.handle_translation_end(movement)

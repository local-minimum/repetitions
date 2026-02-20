extends CharacterBody3D
class_name PhysicsGridPlayerController

static var last_connected_player: PhysicsGridPlayerController
static var last_connected_player_cinematic: bool:
    get():
        return last_connected_player != null && last_connected_player.cinematic

var builder: DungeonBuilder

var cinematic: bool:
    get():
        return cinematic || !_cinematic_blockers.is_empty()

    set(value):
        var _old_value: bool = cinematic
        if value:
            push_warning("Setting cinematic this way means someone else can remove it, use add/remove cinematic blockers instead")
        _update_cinematic(_old_value)

        cinematic = value

var _cinematic_blockers: Array[Node]

func _update_cinematic(old_value: bool) -> void:
    _translation_stack.clear()
    _translation_pressed.clear()

    if !cinematic && old_value && gridless:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        _captured_pointer_eventer.active = true

    elif cinematic && !old_value && gridless:
        _captured_pointer_eventer.active = false

func add_cinematic_blocker(node: Node) -> void:
    if !_cinematic_blockers.has(node):
        var old_value: bool = cinematic
        _cinematic_blockers.append(node)
        _update_cinematic(old_value)

func remove_cinematic_blocker(node: Node) -> void:
    var old_value: bool = cinematic
    _cinematic_blockers.erase(node)
    if _cinematic_blockers.is_empty():
        cinematic = false
    else:
        _update_cinematic(old_value)

@export var _camera: Camera3D
var camera: Camera3D:
    get():
        return _camera

@export var _captured_pointer_eventer: CapturedMouseEventer

@export var _caster_origin: Node3D
@export var _stepper: PhysicsControllerStepCaster

@export var _forward: ShapeCast3D
@export var _left: ShapeCast3D
@export var _right: ShapeCast3D
@export var _backward: ShapeCast3D

@export_range(0, 1) var _translation_duration: float = 0.3
@export_range(0, 1) var _rotation_duration: float = 0.25
@export_range(0, 1) var _refuse_distance_forward: float = 0.2
@export_range(0, 1) var _refuse_distance_other: float = 0.1

@export var _gridded_fudge_distance: float = 0.25

@export var _gridless_translation_speed: float = 5.0
@export var _gridless_rotation_speed: float = 0.8
@export var _gridless_friction: float = 7.0
@export var _mouse_sensitivity_yaw: float = 0.003
@export var _mouse_sensistivity_pitch: float = 0.003
@export var _gridless_camera_near: float = 0.05
@export var _gridless_camera_fov: float = 70

@export var _camera_to_gridless_time: float = 0.2
@export var _camera_to_gridded_time: float = 1.5
@export var _allow_vertical_movement: bool

@export var _focus_default_distance: float = 0.75
@export var _focus_fov: float = 60

@export var _debug_shapes: Array[Node3D]
@export var _show_debug_shapes: bool = false:
    set(value):
        _show_debug_shapes = value
        _sync_debug_shape_visibilities()

var _gridded_cam_offset: Vector3
var _gridless_cam_offset: Vector3
var _gridded_cam_near: float
var _gridded_cam_fov: float

var _cam_slide_tween: Tween
var _translation_tween: Tween
var _rotation_tween: Tween

var _translation_stack: Array[Movement.MovementType]
var _translation_pressed: Dictionary[Movement.MovementType, bool]

## This should be false if instant movement or settings say no
var _allow_continious_translation: bool = true

var gridless: bool:
    set(value):
        if gridless != value:
            # _translation_stack.clear()
            # _translation_pressed.clear()
            velocity = Vector3.ZERO

            if value:
                _captured_pointer_eventer.active = true
                if _cam_slide_tween && _cam_slide_tween.is_running():
                    _cam_slide_tween.kill()
                _cam_slide_tween = create_tween().set_parallel()
                @warning_ignore_start("return_value_discarded")
                _cam_slide_tween.tween_property(_camera, "position", _gridless_cam_offset, _camera_to_gridless_time)
                _cam_slide_tween.tween_property(_camera, "near", _gridless_camera_near, _camera_to_gridless_time)
                _cam_slide_tween.tween_property(_camera, "fov", _gridless_camera_fov, _camera_to_gridless_time)
                @warning_ignore_restore("return_value_discarded")
            else:
                _captured_pointer_eventer.active = false
                if _cam_slide_tween && _cam_slide_tween.is_running():
                    _cam_slide_tween.kill()
                _cam_slide_tween = create_tween().set_parallel()
                @warning_ignore_start("return_value_discarded")
                _cam_slide_tween.tween_property(_camera, "position", _gridded_cam_offset, _camera_to_gridded_time)
                _cam_slide_tween.tween_property(_camera, "near", _gridded_cam_near, _camera_to_gridded_time)
                _cam_slide_tween.tween_property(_camera, "fov", _gridded_cam_fov, _camera_to_gridded_time)
                _cam_slide_tween.tween_property(_camera, "rotation:x", 0, _camera_to_gridded_time)
                @warning_ignore_restore("return_value_discarded")
                # Force alignment with grid.
                # NOTE: move needs to happend before turn
                _attempt_transition_to_gridded_translation()
                _attempt_turn(0.0)

        gridless = value

func _ready() -> void:
    _gridded_cam_offset = _camera.position

    _gridless_cam_offset = _camera.position
    _gridless_cam_offset.x = 0
    _gridless_cam_offset.z = 0

    _gridded_cam_fov = _camera.fov
    _gridded_cam_near = _camera.near

    __SignalBus.on_physics_player_ready.emit(self)
    _captured_pointer_eventer.active = gridless
    _sync_debug_shape_visibilities()
    last_connected_player = self

func _exit_tree() -> void:
    if last_connected_player == self:
        last_connected_player = null

    __SignalBus.on_physics_player_removed.emit(self)

func _input(event: InputEvent) -> void:
    var handled: bool = true
    if event.is_echo():
        return

    if event.is_action_pressed(&"crawl_forward"):
        _push_ontop_of_movement_stack(Movement.MovementType.FORWARD)

    elif event.is_action_released(&"crawl_forward"):
        _release_movement(Movement.MovementType.FORWARD)

    elif event.is_action_pressed(&"crawl_strafe_left"):
        _push_ontop_of_movement_stack(Movement.MovementType.STRAFE_LEFT)

    elif event.is_action_released(&"crawl_strafe_left"):
        _release_movement(Movement.MovementType.STRAFE_LEFT)

    elif event.is_action_pressed(&"crawl_strafe_right"):
        _push_ontop_of_movement_stack(Movement.MovementType.STRAFE_RIGHT)

    elif event.is_action_released(&"crawl_strafe_right"):
        _release_movement(Movement.MovementType.STRAFE_RIGHT)

    elif event.is_action_pressed(&"crawl_backward"):
        _push_ontop_of_movement_stack(Movement.MovementType.BACK)

    elif event.is_action_released(&"crawl_backward"):
        _release_movement(Movement.MovementType.BACK)

    else:
        handled = false

    if handled && !cinematic:
        get_viewport().set_input_as_handled()

    if gridless && event is InputEventMouseMotion && !cinematic:
        var mouse: InputEventMouseMotion = event
        rotation.y -= mouse.relative.x * _mouse_sensitivity_yaw
        var new_pitch: float = _camera.rotation.x - mouse.relative.y * _mouse_sensistivity_pitch
        _camera.rotation.x = clampf(new_pitch, -PI * 2/3, PI * 2/3)

func _sync_debug_shape_visibilities() -> void:
    for shape: Node3D in _debug_shapes:
        shape.visible = _show_debug_shapes

func _push_ontop_of_movement_stack(movement: Movement.MovementType) -> void:
    if cinematic:
        return

    if gridless:
        if !_translation_stack.has(movement):
            _translation_stack.append(movement)
    else:
        _translation_stack.append(movement)
        _translation_pressed[movement] = _allow_continious_translation

func _release_movement(movement: Movement.MovementType) -> void:
    if gridless:
        _translation_stack.erase(movement)

    _translation_pressed[movement] = false


func _physics_process(delta: float) -> void:
    if cinematic:
        return

    if gridless:
        _gridless_movement(delta)
    else:
        _gridfull_movement()

func _gridless_movement(delta: float) -> void:
    var direction: Vector3 = Vector3.ZERO
    if !_translation_stack.is_empty():

        for movement: Movement.MovementType in _translation_stack:
            match movement:
                Movement.MovementType.FORWARD:
                    direction += -basis.z
                Movement.MovementType.STRAFE_LEFT:
                    direction += -basis.x
                Movement.MovementType.STRAFE_RIGHT:
                    direction += basis.x
                Movement.MovementType.BACK:
                    direction += basis.z
                _:
                    push_error("Player %s's movement %s is not a valid translation" % [name, Movement.name(movement)])
        if direction.length_squared() > 1.0:
            direction = direction.normalized()

        if direction.length_squared() > 0.0:

            var v: Vector3 = direction * _gridless_translation_speed
            velocity.x = v.x
            velocity.z = v.z

    else:
        var v: Vector3 = velocity.lerp(Vector3.ZERO, _gridless_friction * delta)
        velocity.x = v.x
        velocity.z = v.z

    var angle: float = 0.0
    if Input.is_action_pressed("crawl_turn_left"):
        angle = TAU * delta * _gridless_rotation_speed
    elif Input.is_action_pressed("crawl_turn_right"):
        angle = -TAU * delta * _gridless_rotation_speed

    if angle != 0.0:
        basis = transform.rotated(Vector3.UP, angle).basis

    if move_and_slide() && direction.length_squared() > 0:
        # Collides with something
        var step_data: Dictionary[PhysicsControllerStepCaster.StepData, Vector3] = {}
        _caster_origin.position = Vector3.ZERO
        _stepper.global_step_direction = direction
        _stepper.step_distance = (direction * velocity).length() * delta

        if _stepper.can_step_up(step_data):
            global_position = step_data[PhysicsControllerStepCaster.StepData.CENTER_POINT]

    elif _show_debug_shapes:
        _stepper.display_debug_not_hitting()

    if !is_on_floor():
        velocity += get_gravity()

func _gridfull_movement() -> void:
    if !_translation_stack.is_empty():
        var movement: Movement.MovementType = _translation_stack[0]
        match movement:
            Movement.MovementType.FORWARD:
                _attempt_gridded_translation(movement, -global_basis.z)
            Movement.MovementType.STRAFE_LEFT:
                _attempt_gridded_translation(movement, -global_basis.x)
            Movement.MovementType.STRAFE_RIGHT:
                _attempt_gridded_translation(movement, global_basis.x)
            Movement.MovementType.BACK:
                _attempt_gridded_translation(movement, global_basis.z)
            _:
                push_error("Player %s's movement %s is not a valid translation" % [name, Movement.name(movement)])

    if Input.is_action_just_pressed("crawl_turn_left"):
        _attempt_turn(PI * 0.5)
    elif Input.is_action_just_pressed("crawl_turn_right"):
        _attempt_turn(-PI * 0.5)

func _calculate_estimated_gridded_translation_target(
    movement: Movement.MovementType = Movement.MovementType.NONE,
    direction: Vector3 = Vector3.ZERO,
) -> Vector3:
    return(
        builder.get_closest_global_neighbour_position(global_position, CardinalDirections.vector_to_direction(direction))
        if movement != Movement.MovementType.NONE else
        builder.get_closest_global_grid_position(global_position)
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
    if _stepper.can_step(step_data, true):
        if step_data[PhysicsControllerStepCaster.StepData.NORMAL].angle_to(Vector3.UP) > floor_max_angle:
            if fudge > 0.0:
                _caster_origin.global_position -= planar_delta.normalized() * fudge
                if _test_step(step_data, planar_delta, 0.0):
                    return true
            print_debug("Failed step from %s at %s due to angle %s, player at %s" % [
                _caster_origin.global_position,
                step_data,
                step_data[PhysicsControllerStepCaster.StepData.NORMAL].angle_to(Vector3.UP),
                global_position
            ])
            return false


        _caster_origin.global_position.y = step_data[PhysicsControllerStepCaster.StepData.CENTER_POINT].y
    else:
        if fudge > 0.0:
            _caster_origin.global_position -= planar_delta.normalized() * fudge
            # Attempt lenient position but no iterative fudging
            return _test_step(step_data, planar_delta, 0.0)

        print_debug("Failed step from %s, player at %s" % [_caster_origin.global_position, global_position])
        return false

    return true

func _attempt_gridded_translation(movement: Movement.MovementType, direction: Vector3, resolution: int = 6) -> void:
    if _translation_tween && _translation_tween.is_running() || _rotation_tween && _rotation_tween.is_running():
        return

    direction = _normalize_gridded_translation_direction(movement, direction)
    var target: Vector3 = _calculate_estimated_gridded_translation_target(movement, direction)
    direction = target - global_position
    # Make direction planar, we'll deal with slopes later on
    direction.y = 0

    var planar_delta: Vector3 = Vector3(direction)
    direction = direction.normalized()

    print_debug("Attempting %s -> %s" % [global_position, target])
    var steps: Array = [
        {
            PhysicsControllerStepCaster.StepData.POINT: global_position,
            PhysicsControllerStepCaster.StepData.CENTER_POINT: global_position,
            PhysicsControllerStepCaster.StepData.NORMAL: Vector3.UP,
        }
    ]

    _stepper.step_distance = 0
    _stepper.global_step_direction = direction
    _caster_origin.position = Vector3.ZERO
    var y: float = global_position.y
    var failed: bool = false
    var fudge: float = minf(_gridded_fudge_distance, (0.8 * planar_delta / float(resolution)).length())
    for idx: int in resolution:
        var step_data:  Dictionary[PhysicsControllerStepCaster.StepData, Vector3]
        _caster_origin.global_position = global_position + planar_delta * float(idx + 1) / float(resolution)
        _caster_origin.global_position.y = y
        if _test_step(step_data, planar_delta, fudge if idx == resolution - 1 else 0.0):
            steps.append(step_data)
            y = _caster_origin.global_position.y
        else:
            failed = true
            break

    _caster_origin.position = Vector3.ZERO

    if failed:
        if steps.size() < 2:
            target = steps[-1][PhysicsControllerStepCaster.StepData.CENTER_POINT]
        var mid: Vector3 = global_position.lerp(target, _refuse_distance_forward if movement == Movement.MovementType.FORWARD else _refuse_distance_other)
        _animate_refused_movement(movement, mid)
        return

    var part_duration: float = _translation_duration / (steps.size() - 1)
    _translation_tween = create_tween()
    var prev_norm: Vector3 = Vector3.UP
    var prev_pt: Vector3 = global_position

    @warning_ignore_start("return_value_discarded")
    print_debug(steps)
    for step: Dictionary in steps:
        var pt: Vector3 = step[PhysicsControllerStepCaster.StepData.CENTER_POINT]
        var norm: Vector3 = step[PhysicsControllerStepCaster.StepData.NORMAL]
        if (
            absf(pt.y - prev_pt.y) < _stepper.ignore_step_height ||
            norm.angle_to(Vector3.UP) > _FLATNESS_THRESHOLD ||
            prev_norm.angle_to(Vector3.UP) > _FLATNESS_THRESHOLD
        ):
            # Flat or slope walk
            _translation_tween.tween_property(
                self,
                "global_position",
                pt,
                part_duration,
            )
        else:
            # We need stairs animation type
            _translation_tween.tween_property(
                self,
                "global_position:x",
                pt.x,
                part_duration,
            )
            _translation_tween.set_parallel()
            _translation_tween.tween_property(
                self,
                "global_position:z",
                pt.z,
                part_duration,
            )
            _translation_tween.tween_property(
                self,
                "global_position:y",
                pt.y,
                part_duration,
            ).set_ease(Tween.EASE_OUT if prev_pt.y < pt.y else Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
            _translation_tween.set_parallel(false)

    @warning_ignore_restore("return_value_discarded")
    if _translation_tween.finished.connect(_handle_translation_end.bind(movement)) != OK:
        push_warning("Failed to connect end of movement")
        _handle_translation_end(movement)

func _attempt_transition_to_gridded_translation() -> void:
    if _translation_tween && _translation_tween.is_running() || _rotation_tween && _rotation_tween.is_running():
        return

    var target: Vector3 = _calculate_estimated_gridded_translation_target()

    _translation_tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    _translation_tween.tween_property(self, "global_position", target, _translation_duration)
    @warning_ignore_restore("return_value_discarded")
    if _translation_tween.finished.connect(_handle_translation_end.bind(Movement.MovementType.CENTER)) != OK:
        push_warning("Failed to connect end of movement")
        _handle_translation_end(Movement.MovementType.CENTER)

func _handle_translation_end(movement: Movement.MovementType) -> void:
    if !_translation_pressed.get(movement, false):
        _translation_stack.erase(movement)

func _animate_refused_movement(movement: Movement.MovementType, mid: Vector3) -> void:
    _translation_tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    _translation_tween.tween_property(self, "global_position", mid, _translation_duration * 0.5)
    _translation_tween.tween_property(self, "global_position", global_position, _translation_duration * 0.5)
    @warning_ignore_restore("return_value_discarded")

    if _translation_tween.finished.connect(_handle_translation_end.bind(movement)) != OK:
        push_error("Failed to connect to translation tween end")
        _handle_translation_end(movement)

func _attempt_turn(angle: float) -> void:
    if  _rotation_tween && _rotation_tween.is_running():
        return

    var t: Transform3D = global_transform.rotated(Vector3.UP, angle)
    var target_global_rotation: Quaternion = builder.get_cardial_rotation(t.basis.get_rotation_quaternion())

    _rotation_tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    var tween_func: Callable = QuaternionUtils.create_tween_rotation_method(self)
    _rotation_tween.tween_method(tween_func, global_transform.basis.get_rotation_quaternion(), target_global_rotation, _rotation_duration)
    @warning_ignore_restore("return_value_discarded")

## Attempts to rotate the character so that it has a wall in the back and looking
## out over an open area
func set_rotation_away_from_wall(force_update: bool = false) -> void:
    if force_update:
        _forward.force_shapecast_update()
        _backward.force_shapecast_update()
        _left.force_shapecast_update()
        _right.force_shapecast_update()

    if !_forward.is_colliding() && _backward.is_colliding():
        return
    elif !_left.is_colliding() && _right.is_colliding():
        rotate_z(0.5 * PI)
    elif !_right.is_colliding() && _left.is_colliding():
        rotate_z(-0.5 * PI)
    elif !_backward.is_colliding() && _forward.is_colliding():
        rotate_z(PI)
    elif !_forward.is_colliding():
        return
    elif !_left.is_colliding():
        rotate_z(0.5 * PI)
    elif !_right.is_colliding():
        rotate_z(-0.5 * PI)
    elif !_backward.is_colliding():
        rotate_z(PI)

    # Were stuck in a 1x1 and no rotation will help

var _focus_obj: Node3D

func focus_on(
    obj: Node3D,
    distance: float = -1,
    ease_duration: float = 0.2,
    vertical_view_bias: float = 1.1,
) -> void:
    if obj == null:
        return

    _focus_obj = obj

    distance = distance if distance > 0 else maxf(distance, _focus_default_distance)

    if _cam_slide_tween != null && _cam_slide_tween.is_running():
        _cam_slide_tween.kill()

    var offset: Vector3 = (_camera.global_position - obj.global_position).normalized()
    var up: Vector3 = offset.project(global_basis.y)
    var lateral: Vector3 = offset - up

    offset = (
        up.normalized() * vertical_view_bias +
        lateral.normalized()
    ).normalized() * distance

    var expected: Vector3 = obj.global_position + offset

    var tw_rot_method: Callable = QuaternionUtils.create_tween_rotation_method(_camera)

    _cam_slide_tween = create_tween().set_parallel()
    @warning_ignore_start("return_value_discarded")
    _cam_slide_tween.tween_property(_camera, "global_position", expected, ease_duration)
    _cam_slide_tween.tween_property(_camera, "near", _gridless_camera_near, ease_duration)
    _cam_slide_tween.tween_property(_camera, "fov", _focus_fov, ease_duration)
    _cam_slide_tween.tween_method(tw_rot_method, _camera.global_basis.get_rotation_quaternion(), Basis.looking_at(-offset).get_rotation_quaternion(), ease_duration)
    @warning_ignore_restore("return_value_discarded")

## If obj is the one in focus then it eases away from it. If not, call is ignored
func defocus_on(obj: Node3D, ease_duration: float = 0.2) -> void:
    if _focus_obj != obj:
        return

    if _cam_slide_tween != null && _cam_slide_tween.is_running():
        _cam_slide_tween.kill()

    var expected_near: float = _gridless_camera_near if gridless else _gridded_cam_near
    var expected_fov: float = _gridless_camera_fov if gridless else _gridded_cam_fov
    var expected: Vector3 = _gridless_cam_offset if gridless else _gridded_cam_offset

    _cam_slide_tween = create_tween().set_parallel()
    @warning_ignore_start("return_value_discarded")
    _cam_slide_tween.tween_property(_camera, "position", expected, ease_duration)
    _cam_slide_tween.tween_property(_camera, "near", expected_near, ease_duration)
    _cam_slide_tween.tween_property(_camera, "fov", expected_fov, ease_duration)
    if !gridless:
        var tw_rot_method: Callable = QuaternionUtils.create_tween_rotation_method(_camera, false)
        _cam_slide_tween.tween_method(tw_rot_method, _camera.basis.get_rotation_quaternion(), Basis.IDENTITY.get_rotation_quaternion(), ease_duration)
    @warning_ignore_restore("return_value_discarded")

static func find_player_in_tree(body: Node3D) -> PhysicsGridPlayerController:
    while body != null:
        if body is PhysicsGridPlayerController:
            return body as PhysicsGridPlayerController

        body = body.get_parent_node_3d()

    return null

extends PhysicsDoor
class_name SwingingDoor

@export var _rotating_node: Node3D

@export var _local_rotation_axis: Vector3 = Vector3.UP
@export var _resting_rotation: float = 0
@export var _open_rotation_deg: Array[float] = [-118.0]
@export var _side_detectors: Array[Node3D] = []
@export var _successful_interaction_after_progress: float = 0.8
@export_range(0.0, 10.0) var _rotation_start_delay: float = 0.0
@export_range(0.0, 2.0) var _rotation_duration: float = 0.7
@export var _animator: AnimationPlayer
@export var _anim_interact: String

var _is_opening: bool
var _motion_blocked: bool
var _motion_block_progress: float
var _tween_progress: float
var _last_open_interaction_target: float = 0
var _tween_target: float
var _tween_start: float

func _ready() -> void:
    _last_open_interaction_target = _resting_rotation

func is_animating() -> bool:
    return _tween != null && _tween.is_running()

func is_open() -> bool:
    var a: float = _rotating_node.rotation_degrees.dot(_local_rotation_axis)
    var best: float = fposmod(a - _resting_rotation, 180)
    for open_a: float in _open_rotation_deg:
        if best > fposmod(a - open_a, 180):
            return true
    return false

func is_opening() -> bool:
    return is_animating() && _is_opening

func _bocking_is_in_motion_direction(interactor: Node3D) -> bool:
    var idx: int = _get_side_of_door_index(interactor)
    if idx < 0:
        return false

    elif _is_opening:
        if _motion_blocked:
            return _last_open_interaction_target != _open_rotation_deg[idx]
        else:
            return _last_open_interaction_target == _open_rotation_deg[idx]

    else:
        if _motion_blocked:
            return _last_open_interaction_target == _open_rotation_deg[idx]
        else:
            return _last_open_interaction_target != _open_rotation_deg[idx]

func _blocking_body_detected(body: PhysicsBody3D) -> void:
    if !is_animating():
        return

    if !_bocking_is_in_motion_direction(body):
        return

    if _motion_blocked:
        if _tween != null && _tween.is_running():
            _tween.kill()
            # print_debug("Rotating Door %s ran into %s while animating back to start, we give up" % [name, body])
            return
    else:
        if _tween_progress > _successful_interaction_after_progress:
            if _tween != null && _tween.is_running():
                _tween.kill()
                # print_debug("Rotating Door %s ran into %s while animating, we are done" % [name, body])
                return

        # print_debug("Rotating Door %s ran into %s while animating, we return back" % [name, body])
        _motion_blocked = true
        _motion_block_progress = _tween_progress
        _tween_target = _tween_start
        _tween_start = _rotating_node.rotation_degrees.dot(_local_rotation_axis)

var _tween: Tween

func _get_rotation_target(interactor: Node3D) -> float:
    # The door was opened last and should now be closed
    if _tween_target != _resting_rotation:
        return _resting_rotation

    # If there's only one direction time to open to it
    if _open_rotation_deg.size() == 1:
        return _open_rotation_deg[0]

    # The door is closed but has been opened before, so if it opens both ways we will try and open the other way
    if _last_open_interaction_target != _resting_rotation:
        var opts: Array[float] = Array(
            _open_rotation_deg.filter(func (a: float) -> bool: return a != _last_open_interaction_target),
            TYPE_FLOAT,
            "",
            null,
        )
        # If it only opens one way we do that
        if opts.is_empty():
            return _open_rotation_deg.pick_random()
        return opts.pick_random()

    # If we don't know which side the interactor is on, we open random direction
    if interactor == null:
        return _open_rotation_deg.pick_random()

    # We attempt to open away from the interactor
    return _get_opposing_rotation_or_random(interactor)

func _get_side_of_door_index(interactor: Node3D) -> int:
    var best_idx: int = -1
    var best_dist_sq: float = 0
    for idx: int in range(_side_detectors.size()):
        var dist_sq: float = _side_detectors[idx].global_position.distance_squared_to(interactor.global_position)
        if best_idx < 0 || dist_sq < best_dist_sq:
            best_idx = idx
            best_dist_sq = dist_sq

    return best_idx

func _get_opposing_rotation_or_random(interactor: Node3D) -> float:
    var best_idx: int = _get_side_of_door_index(interactor)

    if best_idx > -1 && best_idx < _open_rotation_deg.size():
        var open_idx: int = Array(
            range(_open_rotation_deg.size).filter(func (opt_idx: int) -> bool: return opt_idx != best_idx),
            TYPE_INT,
            "",
            null,
        ).pick_random()
        return _open_rotation_deg[open_idx]

    # Give up and just pick at random
    return _open_rotation_deg.pick_random()

func _interact(interactor: Node3D) -> void:
    if _open_rotation_deg.is_empty():
        push_warning("Door cannot be opened")
        return

    if _tween != null && _tween.is_running():
        _tween.kill()

    _motion_blocked = false
    _motion_block_progress = 0
    _tween_start = _rotating_node.rotation_degrees.dot(_local_rotation_axis)
    _tween_target = _get_rotation_target(interactor)
    if _tween_target != _resting_rotation:
        _last_open_interaction_target = _tween_target
        _is_opening = true
    else:
        _is_opening = false

    if _animator != null && !_anim_interact.is_empty():
        _animator.play(_anim_interact)

    if _rotation_start_delay > 0:
        await get_tree().create_timer(_rotation_start_delay).timeout

    _tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    _tween.tween_method(_tweener_func, 0.0, 1.0, _rotation_duration)
    @warning_ignore_restore("return_value_discarded")

func _tweener_func(progress: float) -> void:
    _tween_progress = progress
    _rotating_node.rotation_degrees = lerpf(_tween_start, _tween_target, (progress - _motion_block_progress) / (1.0 - _motion_block_progress)) * _local_rotation_axis

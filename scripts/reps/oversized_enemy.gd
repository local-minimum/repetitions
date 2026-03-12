extends Node3D
class_name OversizedEnemy

enum Looking { FORWARD, LEFT, RIGHT, ANY }
enum Mode { IDLE, MOVING, MELEE, RANGED, ANY }

@export var looking: Looking = Looking.FORWARD
@export var mode: Mode = Mode.IDLE

@export var _anim: AnimationPlayer
@export var _configs: Array[OversizedEnemyAnimConfig]

@export var _track_player_angle_hysteresis: float = PI / 8

var busy: bool:
    get():
        return mode != Mode.IDLE

func _enter_tree() -> void:
    if _anim == null:
        push_error("No animator connected to %s" % [self])
    elif _anim.current_animation_changed.connect(_handle_animation_changed) != OK:
        push_error("Failed to connect animation changed")

func _ready() -> void:
    _update_anim(current_anim_conf, 0.0)
    _demo()

func _demo() -> void:
    while true:
        await get_tree().create_timer(2.0).timeout
        if randf() < 0.8:
            _check_track_player()

func _check_track_player() -> void:
    if busy:
        #print_debug("We are busy, no looking update")
        return

    var player: PhysicsGridPlayerController = PhysicsGridPlayerController.last_connected_player

    if player == null:
        push_warning("%s has no player to track, no looking update" % [self])
        return

    var d_player: Vector3 = player.global_position - global_position
    var forward: Vector3 = -global_basis.z
    var up: Vector3 = global_basis.y
    var angle: float = forward.signed_angle_to(d_player, up)
    var new_looking: Looking = _get_wanted_looking(angle)
    var conf: OversizedEnemyAnimConfig = get_looking_transition_conf(new_looking)
    #print_debug("Resulting looking %s has conf %s" % [Looking.find_key(new_looking), conf])

    if conf != null:
        looking = new_looking
        _update_anim(conf, conf.custom_next_anim_blend)

func _get_wanted_looking(angle: float) -> Looking:
    #print_debug("Calculating looking from %s based on angle %s to player" % [Looking.find_key(looking), angle])
    var quartpi: float = PI / 4
    match looking:
        Looking.FORWARD:
            if angle > - quartpi - _track_player_angle_hysteresis && angle < quartpi + _track_player_angle_hysteresis:
                return Looking.FORWARD
            elif angle < 0:
                return Looking.RIGHT
            else:
                return Looking.LEFT
        Looking.RIGHT:
            if angle > -PI && angle < -quartpi + _track_player_angle_hysteresis || angle > PI - _track_player_angle_hysteresis:
                return Looking.RIGHT
            else:
                return Looking.FORWARD
        Looking.LEFT:
            if angle < PI && angle > quartpi - _track_player_angle_hysteresis || angle < -PI + _track_player_angle_hysteresis:
                return Looking.LEFT
            else:
                return Looking.FORWARD
        _:
            push_error("Unhandled looking direction %s" % [Looking.find_key(looking)])
            return Looking.FORWARD

var current_anim_conf: OversizedEnemyAnimConfig:
    get():
        for conf: OversizedEnemyAnimConfig in _configs:
            if conf.mode == mode && conf.looking == looking:
                return conf

        push_error("Missing animation config for mode %s and looking %s" % [
            Mode.find_key(mode),
            Looking.find_key(looking)
        ])
        return null

func get_looking_transition_conf(to_look: Looking) -> OversizedEnemyAnimConfig:
    for conf: OversizedEnemyAnimConfig in _configs:
        if (
            (conf.prev_looking == looking || conf.prev_looking == Looking.ANY) &&
            (conf.looking == to_look || conf.looking == Looking.ANY) &&
            (conf.mode == mode || conf.mode == Mode.ANY)
        ):
            return conf

    push_warning("Missing animation config for look transition from %s to %s during mode %s" % [
        Looking.find_key(looking),
        Looking.find_key(to_look),
        Mode.find_key(mode),
    ])
    return null

func _handle_animation_changed(_anim_name: String) -> void:
    if !_anim_name.is_empty():
        return

    var blend: float = -1.0
    var conf: OversizedEnemyAnimConfig = current_anim_conf

    if conf != null:
        blend = conf.custom_next_anim_blend
        if conf.next_mode != Mode.ANY:
            mode = conf.next_mode

    _update_anim(current_anim_conf, blend)

func _update_anim(conf: OversizedEnemyAnimConfig, blend: float = -1) -> void:
    if conf != null:
        _anim.play(conf.anim_name, blend, 1.0, conf.anim_from_end)
        print_debug("Executing animation %s" % [conf])
    else:
        push_warning("Found no animation for %s %s" % [Looking.find_key(looking), Mode.find_key(mode)])

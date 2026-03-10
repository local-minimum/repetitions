extends Node3D
class_name OversizedEnemy

enum Looking { FORWARD, LEFT, RIGHT, ANY }
enum Mode { IDLE, MOVING, MELEE, RANGED, ANY }

@export var looking: Looking = Looking.FORWARD
@export var mode: Mode = Mode.IDLE

@export var _anim: AnimationPlayer
@export var _configs: Array[OversizedEnemyAnimConfig]

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
        if randf() < 0.5:
            var new_looking: Looking
            if looking == Looking.LEFT || looking == Looking.RIGHT:
                new_looking = Looking.FORWARD
            else:
                new_looking = Looking.LEFT if randf() < 0.5 else Looking.RIGHT

            var conf: OversizedEnemyAnimConfig = get_looking_transition_conf(new_looking)
            print_debug("Change animation: %s -> %s => %s" % [
                Looking.find_key(looking),
                Looking.find_key(new_looking),
                conf,
            ])
            if conf != null:
                looking = new_looking
                _update_anim(conf, conf.custom_next_anim_blend)

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

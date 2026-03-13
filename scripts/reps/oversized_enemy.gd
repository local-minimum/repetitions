extends Node3D
class_name OversizedEnemy

enum Looking { FORWARD, LEFT, RIGHT, ANY }
enum Mode { IDLE, MOVING, MELEE, RANGED, ANY }

@export var looking: Looking = Looking.FORWARD
@export var mode: Mode = Mode.IDLE

@export var _anim: AnimationPlayer
@export var _configs: Array[OversizedEnemyAnimConfig]

@export var _track_player_angle_hysteresis: float = PI / 8
@export var _fish_root: Node3D
@export var _side_looking_forward_offset: float = 0.25
@export var _side_looking_tween_duration: float = 0.25

@export var _ranged_cooldown_msec: int = 1500
@export var _melee_cooldown_msec: int = 500

@export var _eyes: LookRayCast
@export var _mouth: Node3D

@export var _projectile_delay: float = 0.2
@export var _projectile_scene: PackedScene

var looking_global_direction: Vector3:
    get():
        match looking:
            Looking.FORWARD:
                return -global_basis.z
            Looking.LEFT:
                return -global_basis.x
            Looking.RIGHT:
                return global_basis.x
            _:
                push_error("Unhandled looking %s" % [Looking.find_key(looking)])
                return -global_basis.z

var _fish_root_tween: Tween
var _fish_root_origin: Vector3
var _busy_until_change_anim: bool
var _next_melee_time: int
var _next_ranged_time: int

var busy: bool:
    get():
        return _busy_until_change_anim || mode != Mode.IDLE

func _enter_tree() -> void:
    if _anim == null:
        push_error("No animator connected to %s" % [self])
    elif _anim.current_animation_changed.connect(_handle_animation_changed) != OK:
        push_error("Failed to connect animation changed")

    _fish_root_origin = _fish_root.position

func _ready() -> void:
    _update_anim(current_anim_conf, 0.0)
    _busy_until_change_anim = true

func _process(_delta: float) -> void:
    if busy:
        return

    var player: PhysicsGridPlayerController = PhysicsGridPlayerController.last_connected_player
    if player == null:
        return

    var sees_player: bool = _eyes.sees_player(player)

    if _check_melee_player(player):
        mode = Mode.MELEE
        _next_melee_time = Time.get_ticks_msec() + _melee_cooldown_msec
        var conf: OversizedEnemyAnimConfig = current_anim_conf
        _update_anim(conf, conf.custom_next_anim_blend)

    elif sees_player && _check_ranged_player(player):
        mode = Mode.RANGED
        _next_ranged_time = Time.get_ticks_msec() + _ranged_cooldown_msec
        var conf: OversizedEnemyAnimConfig = current_anim_conf
        _update_anim(conf, conf.custom_next_anim_blend)
        await get_tree().create_timer(_projectile_delay).timeout
        var projectile: Projectile = _projectile_scene.instantiate()
        DungeonBuilder.active_builder.add_child(projectile)

        if projectile.on_hit.connect(_record_projectile_hit.bind(global_position, player), CONNECT_ONE_SHOT) != OK:
            push_error("Failed to connect projectile hit")

        if projectile.on_miss.connect(_record_projectile_miss.bind(global_position, player), CONNECT_ONE_SHOT) != OK:
            push_error("Failed to connect projectile miss")

        projectile.launch(_mouth.global_position, player.look_target.global_position)


    elif _hunt_player(player):
        print_debug("Hunt")

    elif _check_and_track_player(player):
        print_debug("Track")
    else:
        _idle()

func _record_projectile_hit(body: Node3D, projectile: Projectile, my_position: Vector3, player: PhysicsGridPlayerController) -> void:
    projectile.on_miss.disconnect(_record_projectile_miss)

    if !NodeUtils.is_parent(player, body):
        _record_projectile_miss(player, projectile, my_position)
        return

    print_debug("Hurt player based on %s hit" % [projectile])

func _record_projectile_miss(player: PhysicsGridPlayerController, projectile: Projectile, my_position: Vector3) -> void:
    if projectile.on_hit.is_connected(_record_projectile_hit):
        projectile.on_hit.disconnect(_record_projectile_hit)

func _idle() -> void:
    # TODO: Improve flipping around by avoiding looking into walls if possible
    var new_look: Looking = Looking.FORWARD
    var conf: OversizedEnemyAnimConfig
    if randf() < 0.5:
        match looking:
            Looking.FORWARD:
                new_look = Looking.LEFT if randf() < 0.5 else Looking.RIGHT
                conf = get_looking_transition_conf(new_look)
            Looking.LEFT:
                conf = get_looking_transition_conf(Looking.FORWARD)
            Looking.RIGHT:
                conf = get_looking_transition_conf(Looking.FORWARD)

        if conf != null:
            looking = new_look
            _update_anim(conf, conf.custom_next_anim_blend)

    _busy_until_change_anim = true

func _hunt_player(player: PhysicsGridPlayerController) -> bool:
    # TODO: Improve metric for hunting to be a little smarter perhaps...
    # I.e. last seen duration, stuff like that. Have been hurt...
    var delta: float = ((player.global_position - global_position).abs() / DungeonBuilder.active_builder.grid_size).length()
    return delta < 10.0 && delta >= 5.5

func _check_ranged_player(player: PhysicsGridPlayerController) -> bool:
    if Time.get_ticks_msec() < _next_ranged_time:
        return false

    var delta: float = ((player.global_position - global_position).abs() / DungeonBuilder.active_builder.grid_size).length()
    return delta > 1.5 && delta < 5.5

func _check_melee_player(player: PhysicsGridPlayerController) -> bool:
    if Time.get_ticks_msec() < _next_melee_time:
        return false

    var d_player: Vector3 = player.global_position - global_position
    d_player /= DungeonBuilder.active_builder.grid_size
    var look: Vector3 = looking_global_direction
    # print_debug("Delta %s vs look %s" % [d_player, look])
    if absf(d_player.y) < 1.0 && absf(d_player.x) + absf(d_player.z) <= 1.1:
        if absf(d_player.x) > absf(d_player.z):
            return signf(d_player.x) == signf(look.x)
        else:
            return signf(d_player.z) == signf(look.z)
    return false

func _check_and_track_player(player: PhysicsGridPlayerController) -> bool:
    if player == null:
        push_warning("%s has no player to track, no looking update" % [self])
        return false

    var d_player: Vector3 = player.global_position - global_position
    var forward: Vector3 = -global_basis.z
    var up: Vector3 = global_basis.y
    var angle: float = forward.signed_angle_to(d_player, up)
    var new_looking: Looking = _get_wanted_looking(angle)
    var conf: OversizedEnemyAnimConfig = get_looking_transition_conf(new_looking)
    #print_debug("Resulting looking %s has conf %s" % [Looking.find_key(new_looking), conf])

    if conf != null:
        _handle_looking_transition(new_looking)
        looking = new_looking
        _busy_until_change_anim = true
        _update_anim(conf, conf.custom_next_anim_blend)
        return true

    return false

func _handle_looking_transition(new_looking: Looking) -> void:
    if new_looking == looking:
        return

    if _fish_root_tween != null && _fish_root_tween.is_running():
        _fish_root_tween.kill()

    var target_position: Vector3 = _fish_root_origin
    if new_looking != Looking.FORWARD:
        target_position += -_fish_root.basis.z * _side_looking_forward_offset

    _fish_root_tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    _fish_root_tween.tween_property(_fish_root, "position", target_position, _side_looking_tween_duration)
    @warning_ignore_restore("return_value_discarded")

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

func get_conf_by_animation_name_and_current_looking(anim_name: String) -> OversizedEnemyAnimConfig:
    for conf: OversizedEnemyAnimConfig in _configs:
        if conf.looking == looking && conf.anim_name == anim_name:
            return conf
    return null

func _handle_animation_changed(anim_name: String) -> void:
    _busy_until_change_anim = false

    var conf: OversizedEnemyAnimConfig = null
    if !anim_name.is_empty():
        conf = get_conf_by_animation_name_and_current_looking(anim_name)
        if conf != null:
            if conf.mode != Mode.ANY:
                mode = conf.mode
            elif conf.next_mode != Mode.ANY:
                mode = conf.next_mode
        return

    var blend: float = -1.0
    conf = current_anim_conf

    if conf != null:
        blend = conf.custom_next_anim_blend
        if conf.next_mode != Mode.ANY:
            mode = conf.next_mode

    _update_anim(current_anim_conf, blend)

func _update_anim(conf: OversizedEnemyAnimConfig, blend: float = -1) -> void:
    if conf != null:
        _anim.play(conf.anim_name, blend, conf.anim_speed, conf.anim_from_end)
        print_debug("Executing animation %s" % [conf])
    else:
        push_warning("Found no animation for %s %s" % [Looking.find_key(looking), Mode.find_key(mode)])

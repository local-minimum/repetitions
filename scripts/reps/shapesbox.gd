extends Node3D
class_name ShapesBox

@export var _cylinder: Node3D
@export var _cylinder_rotation_axis: Vector3 = Vector3.RIGHT
@export var _cylinder_start_rotation_degrees: float = -270.0
@export var _cylinder_rotation_per_key: float = -45.0
@export var _cylinder_rotation_duration: float = 0.5
@export var _cylinder_rotation_delay: Dictionary[ToolKey.KeyVariant, float]
@export var _cylidner_default_delay: float = 0.5
@export var _anim: AnimationPlayer
@export var _key_2_anim: Dictionary[ToolKey.KeyVariant, String]

var _deposited_keys: int = 0
var _cylinder_rotation_tween: Tween

func _ready() -> void:
    _sync_cylinder_rotation()

var _cylinder_target_rotation: Vector3:
    get():
        return _cylinder_rotation_axis * (
            _cylinder_start_rotation_degrees + _deposited_keys * _cylinder_rotation_per_key
        )

func _sync_cylinder_rotation() -> void:
    print_debug("Rotate to %s because of %s keys" % [_cylinder_target_rotation, _deposited_keys])
    _cylinder.rotation_degrees = _cylinder_target_rotation

func deposit_key(key: ToolKey.KeyVariant) -> void:
    if _anim != null && _key_2_anim.has(key):
        PhysicsGridPlayerController.last_connected_player.add_cinematic_blocker(self)
        PhysicsGridPlayerController.last_connected_player.focus_on(self)
        var clip: String = _key_2_anim[key]
        _anim.play(clip)

        __SignalBus.on_deposited_tool_key.emit(_deposited_keys, key)

        var delay: float = _cylinder_rotation_delay.get(key, _cylidner_default_delay)
        await get_tree().create_timer(delay).timeout

        _inc_deposited_keys(key)

func _inc_deposited_keys(key: ToolKey.KeyVariant) -> void:
    _deposited_keys += 1
    if _cylinder_rotation_tween != null && _cylinder_rotation_tween.is_running():
        _cylinder_rotation_tween.kill()

    _cylinder_rotation_tween = create_tween()

    @warning_ignore_start("return_value_discarded")
    _cylinder_rotation_tween.tween_property(
        _cylinder,
        "rotation_degrees",
        _cylinder_target_rotation,
        _cylinder_rotation_duration,
    ).set_trans(Tween.TRANS_SINE)
    @warning_ignore_restore("return_value_discarded")

    if _cylinder_rotation_tween.finished.connect(
        func () -> void:
            __SignalBus.on_deposited_tool_key.emit(_deposited_keys, key)
            await get_tree().create_timer(2).timeout
            _setup_wait_for_timeline(PhysicsGridPlayerController.last_connected_player)
    ) != OK:
        await get_tree().create_timer(_cylinder_rotation_duration).timeout
        __SignalBus.on_deposited_tool_key.emit(_deposited_keys, key)
        await get_tree().create_timer(3).timeout
        _setup_wait_for_timeline(PhysicsGridPlayerController.last_connected_player)

func _on_interaction_body_execute_interaction() -> void:
    if __GlobalGameState.carried_keys.is_empty():
        __SignalBus.on_look_at_shapesbox.emit()
        var player: PhysicsGridPlayerController = PhysicsGridPlayerController.last_connected_player
        player.add_cinematic_blocker(self)
        player.focus_on(self)
        await get_tree().create_timer(2).timeout
        _setup_wait_for_timeline(player)
    else:
        deposit_key(__GlobalGameState.carried_keys[0])


func _setup_wait_for_timeline(player: PhysicsGridPlayerController) -> void:
    if Dialogic.current_timeline == null:
        _defocus_self(player)
    else:
        if Dialogic.timeline_ended.connect(func () -> void: _defocus_self(player), CONNECT_ONE_SHOT) != OK:
            push_error("Failed to connect timeline ended")
            _defocus_self(player)

func _defocus_self(player: PhysicsGridPlayerController) -> void:
    player.defocus_on(self)
    player.remove_cinematic_blocker(self)

extends EquippedTool
class_name EquippedTrack

@export var _held_track_piece: Node3D
@export var _placed_track: PackedScene
@export var _laydown_duration: float = 1.0

func execute_action(target: Node3D, __caster: ShapeCast3D) -> void:
    print_debug("Laying down on %s" % [target])

    var track_pos: LooseTrackPosition = LooseTrackPosition.find_in_tree(target)
    if track_pos == null || track_pos.occupied || !track_pos.allowed:
        return

    enabled = false
    track_pos.occupied = true

    var track: Node3D = _placed_track.instantiate()
    track_pos.add_child(track)

    track.global_position = _held_track_piece.global_position
    track.global_rotation = _held_track_piece.global_rotation

    var tween: Tween = track.create_tween()
    @warning_ignore_start("return_value_discarded")
    tween.tween_property(track, "global_position", track_pos.global_position, _laydown_duration)
    tween.parallel().tween_method(
        QuaternionUtils.create_tween_rotation_progress_method(
            track,
            track.global_basis.get_rotation_quaternion(),
            track_pos.global_basis.get_rotation_quaternion(),
        ),
        0.0,
        1.0,
        _laydown_duration,
    )
    @warning_ignore_restore("return_value_discarded")

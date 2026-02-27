@tool
extends Node3D
class_name TrackFollow

@export var current_track: Track
@export var vertical_offset: float = 0

@export var offset_tolerance: float = 0.1
## If the thing is moving forwards along the track direction or not
@export var moving_in_track_forwards_direction: bool = true

## If the thing is looking in the direction it is traveling
@export var reversing: bool = false

@export var upstream_connector: Node3D
@export var downstream_connector: Node3D

var global_distance_to_upstream_connector: float:
    get():
        var global_delta: Vector3 = upstream_connector.global_position - global_position
        global_delta -= global_delta.project(global_basis.y)
        return global_delta.length()

var global_distance_to_downstream_connector: float:
    get():
        var global_delta: Vector3 = downstream_connector.global_position - global_position
        global_delta -= global_delta.project(global_basis.y)
        return global_delta.length()

@warning_ignore_start("unused_private_class_variable")
@export_tool_button("Force Snap") var _do_snap: Callable = snap_to_track
@warning_ignore_restore("unused_private_class_variable")

var ref_position: Vector3:
    get():
        return global_position - global_basis.y * vertical_offset

func snap_to_track() -> void:
    if current_track == null:
        return

    _sync_position(current_track.get_track_point_global(ref_position))

func _sync_position(track_data: Track.PointData) -> void:
    global_position = track_data.point + global_basis.y * vertical_offset

    #if !track_data.at_edge:
    var gb: Basis = Basis.looking_at(
        track_data.forward,
        track_data.up,
    )
    gb = gb.rotated(track_data.up, 0.0 if moving_in_track_forwards_direction != reversing else PI).orthonormalized()

    global_basis = gb

func manage_track_transition(next_track: Track, track_point: Track.PointData) -> Track.PointData:
    var off: float = current_track.get_offset_overshoot(track_point.offset_distance)

    if next_track != current_track && current_track.is_mirrored_connection_direction(next_track, track_point.at_start):
        # We are inverted in directionality
        if track_point.at_start:
            moving_in_track_forwards_direction = true
        else:
            moving_in_track_forwards_direction = false
            off = next_track.get_offset_from_end(off)

    elif track_point.at_start:
        off = next_track.get_offset_from_end(off)

    print_debug("Updated offset switching %s -> %s from %s to %s" % [
        current_track, next_track, track_point.offset_distance,
        off,
    ])
    current_track = next_track
    return next_track.get_offset_position_global(off, true)

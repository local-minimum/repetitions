@tool
extends Node3D
class_name TrackFollow

@export var current_track: Track
@export var vertical_offset: float = 0

#@export var offset_tolerance: float = 0.1

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

    global_basis = Basis.looking_at(
        track_data.forward,
        track_data.up,
    )

func manage_track_transition(
    track: Track,
    next_track: Track,
    track_point: Track.PointData,
    invert_directions: bool,
) -> Track.PointData:
    var overshoot: float = track.get_offset_overshoot(track_point.offset_distance)
    #var transition_progress: float = track.get_transition_progress(track_point.offset_distance, next_track)
    var off: float = overshoot

    if track.is_mirrored_connection_direction(next_track, track_point.at_start):
        # We are inverted in directionality
        if track_point.at_start:
            moving_in_track_forwards_direction = !invert_directions
        else:
            moving_in_track_forwards_direction = invert_directions
            off = next_track.get_offset_from_end(off)

    elif track_point.at_start:
        off = next_track.get_offset_from_end(off)

    #print_debug("Updated %s offset switching %s (at start %s) -> %s (mirrored %s) from %s (over: %s) to %s" % [
    #    name, current_track, track_point.at_start, next_track,
    #    current_track.is_mirrored_connection_direction(next_track, track_point.at_start),
    #    track_point.offset_distance, overshoot,
    #    off,
    #])

    #print_debug("%s is easing from %s to %s with progress %s" % [self, track, next_track, transition_progress])

    var next_track_point: Track.PointData = next_track.get_offset_position_global(
        off,
        moving_in_track_forwards_direction == reversing,
        true,
)

    #if transition_progress > 0.5:
    current_track = next_track


    #return track_point.lerp(next_track_point, transition_progress)
    return next_track_point

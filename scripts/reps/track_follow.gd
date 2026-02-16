@tool
extends Node3D
class_name TrackFollow

@export var current_track: Track
@export var vertical_offset: float = 0:
    set(value):
        vertical_offset = value
        snap_to_track()

@export var offset_tolerance: float = 0.1
@export var travel_forward: bool = true:
    set(value):
        travel_forward = value
        snap_to_track()

var _position: Track.PointData

@warning_ignore_start("unused_private_class_variable")
@export_tool_button("Force Snap") var _do_snap: Callable = _force_snap
@warning_ignore_restore("unused_private_class_variable")


func _force_snap() -> void:
    snap_to_track(true)

func snap_to_track(force: bool = false) -> void:
    print_debug("Snapping to track")
    if current_track == null:
        return

    var ref_position: Vector3 = global_position - global_basis.y * vertical_offset
    _position = current_track.get_track_point_global(ref_position)
    _sync_position(force)

func _sync_position(force: bool) -> void:
    var ref_position: Vector3 = global_position - global_basis.y * vertical_offset

    if !force && pow(offset_tolerance, 2) < ref_position.distance_squared_to(_position.point):
        return

    global_position = _position.point + global_basis.y * vertical_offset

    if !_position.at_edge:
        var gb: Basis = Basis.looking_at(
            _position.forward,
            global_basis.y,
        )
        gb = gb.rotated(Vector3.UP, 0.0 if travel_forward else PI).orthonormalized()


        global_basis = gb

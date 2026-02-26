@tool
extends Path3D
class_name Track

enum ConnectionMode { NONE, STOP, TRACK }
@export var start_mode: ConnectionMode
@export var start_connections: Array[Track]
@export var end_mode: ConnectionMode
@export var end_connections: Array[Track]
@export var handover_margin: float = 0.05

class PointData:
    var point: Vector3
    var offset_distance: float
    var forward: Vector3
    var up: Vector3
    var at_edge: bool

    var at_start: bool:
        get():
            return at_edge && offset_distance <= 0

    @warning_ignore_start("shadowed_variable")
    func _init(point: Vector3, offset_distance: float, at_edge: bool, forward: Vector3, up: Vector3) -> void:
        @warning_ignore_restore("shadowed_variable")
        self.point = point
        self.offset_distance = offset_distance
        self.forward = forward
        self.up = up
        self.at_edge = at_edge

func get_track_point_global(global_point: Vector3) -> PointData:
    var local: Vector3 = to_local(global_point)
    var offset: float = curve.get_closest_offset(local)
    var trans: Transform3D = curve.sample_baked_with_rotation(offset)
    var forward: Vector3 = trans.basis.z
    var up: Vector3 = trans.basis.y

    return PointData.new(
        to_global(trans.origin),
        offset,
        offset <= 0 || offset >= curve.get_baked_length(),
        (to_global(forward) - global_position).normalized(),
        (to_global(up) - global_position).normalized(),
    )

func get_offset_position_global(offset: float, cubic: bool = false) -> PointData:
    var trans: Transform3D = curve.sample_baked_with_rotation(offset, cubic)
    var forward: Vector3 = trans.basis.z
    var up: Vector3 = trans.basis.y

    return PointData.new(
        to_global(trans.origin),
        offset,
        offset <= 0 || offset >= curve.get_baked_length(),
        (to_global(forward) - global_position).normalized(),
        (to_global(up) - global_position).normalized(),
    )

func get_next_track(at_start: bool) -> Track:
    match (start_mode if at_start else end_mode):
        ConnectionMode.TRACK:
            if at_start:
                return start_connections.pick_random()
            return end_connections.pick_random()
    return null

func is_mirrored_connection_direction(connected_track: Track, at_start: bool) -> bool:
    var other_start: Vector3 = connected_track.to_global(connected_track.curve.get_point_position(0))
    var other_end: Vector3 = connected_track.to_global(connected_track.curve.get_point_position(connected_track.curve.point_count - 1))

    if at_start:
        var self_start: Vector3 = to_global(curve.get_point_position(0))
        return self_start.distance_squared_to(other_start) < self_start.distance_squared_to(other_end)
    else:
        var self_end: Vector3 = to_global(curve.get_point_position(curve.point_count - 1))
        return self_end.distance_squared_to(other_start) < self_end.distance_squared_to(other_end)

func get_offset_overshoot(offset: float) -> float:
    if offset < 0:
        return abs(offset)

    return maxf(0, offset - curve.get_baked_length())


func get_offset_from_end(offset: float) -> float:
    return curve.get_baked_length() - offset

func get_connection_mode(point: PointData) -> ConnectionMode:
    if point.at_edge:
        return start_mode if point.at_start else end_mode
    return ConnectionMode.NONE

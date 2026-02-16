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

    @warning_ignore_start("shadowed_variable")
    func _init(point: Vector3, offset_distance: float, forward: Vector3) -> void:
        @warning_ignore_restore("shadowed_variable")
        self.point = point
        self.offset_distance = offset_distance
        self.forward = forward

func get_track_point_global(global_point: Vector3) -> PointData:
    var local: Vector3 = to_local(global_point)
    var offset: float = curve.get_closest_offset(local)
    var trans: Transform3D = curve.sample_baked_with_rotation(offset)
    var forward: Vector3 = trans.basis.z

    return PointData.new(
        to_global(trans.origin),
        offset,
        (to_global(forward) - global_position).normalized(),
    )

func get_offset_position_global(offset: float, cubic: bool = false) -> PointData:
    var trans: Transform3D = curve.sample_baked_with_rotation(offset, cubic)
    var forward: Vector3 = trans.basis.z

    return PointData.new(
        to_global(trans.origin),
        offset,
        (to_global(forward) - global_position).normalized(),
    )

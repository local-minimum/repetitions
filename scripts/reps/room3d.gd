extends Node3D
class_name Room3D

var builder: DungeonBuilder
var blueprint: BlueprintRoom
var origin: Vector3i

@export var _managed_door_configs: Array[DoorConfigurationOptions]

func _exit_tree() -> void:
    if __GlobalGameState.current_player_room == self:
        __GlobalGameState.current_player_room = null

## When room has already been placed we still have to check if something updated
## after new rooms got placed. We don't need to care for new door to door connections
## as this is handled by the newly placed room, but the status of some door leading
## to dirt may have changed
func update_doors_states(doors: Array[DoorData]) -> void:
    for door: DoorData in doors:
        if door.type == DoorData.Type.DOOR_TO_DOOR || door.room != blueprint:
            continue

        var conf: DoorConfigurationOptions = _get_config_for_door_data(door)
        if conf == null || conf.finalized:
            continue

        _resolve_conf_with_door_data(conf, door)

## We deal with all doors except for doors that leads to other doors that aren't yet placed
func configure_door_states(doors: Array[DoorData], placed_rooms: Array[Room3D]) -> void:
    var blueprints: Array[BlueprintRoom] = []
    blueprints.assign(placed_rooms.map(func (r: Room3D) -> BlueprintRoom: return r.blueprint))

    for door: DoorData in doors:
        var other_room_idx: int = blueprints.find(door.other_room)

        if (
            door.type == DoorData.Type.DOOR_TO_DOOR &&
            door.room != self &&
            other_room_idx < 0
        ):
            continue

        var conf: DoorConfigurationOptions = _get_config_for_door_data(door)
        if conf == null:
            continue

        _resolve_conf_with_door_data(conf, door, placed_rooms[other_room_idx])

func _resolve_conf_with_door_data(
    conf: DoorConfigurationOptions,
    door: DoorData,
    other_room: Room3D = null,
) -> void:
    match door.type:
        DoorData.Type.DOOR_TO_DOOR:
            conf.resolve_connected_doors(self, other_room, other_room._get_config_for_door_data(door.reflect()))
        DoorData.Type.DOOR_TO_WALL:
            conf.resolve_door_to_wall(other_room)
        DoorData.Type.DOOR_TO_DIRT:
            conf.resolve_door_to_nothing()
        _:
            conf.resolve_panic()

func _translate_2d_coords_to_3d(coords: Vector2i) -> Vector3i:
    return Vector3i(coords.x, origin.y, coords.y)

func _get_config_for_door_data(door: DoorData) -> DoorConfigurationOptions:
    for conf: DoorConfigurationOptions in _managed_door_configs:
        if builder.is_between_coordinates(
            conf,
            _translate_2d_coords_to_3d(door.global_coordinates),
            _translate_2d_coords_to_3d(door.other_global_coordinates),
        ):
            return conf
    return null

static func find_room(node: Node) -> Room3D:
    if node is Room3D:
        return node as Room3D

    if node == null:
        return null

    return find_room(node.get_parent())

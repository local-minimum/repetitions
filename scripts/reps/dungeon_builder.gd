extends Node3D

@export var grid_size: Vector3

var placed_rooms: Array[Node3D]
const _BLUEPRINT_META: String = "blueprint"
const _ORIGIN_META: String = "origin"

func _enter_tree() -> void:
    if __SignalBus.on_complete_dungeon_plan.connect(_handle_complete_dungeon_plan) != OK:
        push_error("Failed to connect complete dungeon plan")

func _exit_tree() -> void:
    __SignalBus.on_complete_dungeon_plan.disconnect(_handle_complete_dungeon_plan)
    
func _handle_complete_dungeon_plan(elevation: int, rooms: Array[BlueprintRoom]) -> void:
    for room: BlueprintRoom in rooms:
        if room.option == null:
            push_error("Bluepint Room %s lacks an option, no clue what room to place" % room)
            continue
        
        var room_3d: Node3D = room.option.instantiate_3d_room()
        placed_rooms.append(room_3d)
        room_3d.set_meta(_BLUEPRINT_META, room)
        add_child(room_3d)
        
        room_3d.rotation = CardinalDirections.direction_to_rotation(
            CardinalDirections.CardinalDirection.UP, 
            room.get_rotation_direction(),
        ).get_euler()
        
        var origin2d: Vector2i = room.get_origin()
        var origin: Vector3i = Vector3i(origin2d.x, elevation, origin2d.y)
        
        room_3d.position = Vector3(grid_size.x * origin.x, grid_size.y * origin.y, grid_size.z * origin.z)
        room_3d.set_meta(_ORIGIN_META, origin) 

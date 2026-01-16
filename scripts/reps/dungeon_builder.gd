extends Node3D
class_name DungeonBuilder

@export var grid_size: Vector3
@export var player: PhysicsGridPlayerController

var placed_rooms: Array[Node3D]
const _BLUEPRINT_META: String = "blueprint"
const _ORIGIN_META: String = "origin"

func _enter_tree() -> void:
    if __SignalBus.on_complete_dungeon_plan.connect(_handle_complete_dungeon_plan) != OK:
        push_error("Failed to connect complete dungeon plan")

func _exit_tree() -> void:
    __SignalBus.on_complete_dungeon_plan.disconnect(_handle_complete_dungeon_plan)

func _ready() -> void:
    player.cinematic = true
    
func _handle_complete_dungeon_plan(elevation: int, rooms: Array[BlueprintRoom]) -> void:
    var first_room: bool = true
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
        
        if first_room && player != null:
            var ppos: Vector2i = room.get_global_used_tiles()[0]
            player.global_position = to_global(Vector3((ppos.x + 0.5) * grid_size.x, elevation * grid_size.y, (ppos.y + 0.5) * grid_size.z))
            player.builder = self
            first_room = false
            
    player.cinematic = false
    # player.gridless = true
    
func _round_to_floor_center(local: Vector3) -> Vector3:
    var offset: Vector3 = 0.5 * grid_size
    offset.y = 0
    return ((local - offset) / grid_size).round() * grid_size + offset
    
func get_floor_center(global_origin: Vector3, global_translation_direction: Vector3) -> Vector3:
    var direction: Vector3 = to_local(global_translation_direction + global_position).normalized()
    var target: Vector3 = to_local(global_origin) + direction * grid_size
    # print_debug("%s with %s/%s -> %s -> %s/%s" % [
    #    to_local(global_origin), global_translation_direction, direction, target,
    #     _round_to_floor_center(target),
    #    to_global(_round_to_floor_center(target))])
    return to_global(_round_to_floor_center(target))

func get_cardial_rotation(global_quat: Quaternion) -> Quaternion:
    var quats: Array[Quaternion] = [
        self.global_basis.get_rotation_quaternion(),
        self.global_basis.rotated(Vector3.UP, PI * 0.5).get_rotation_quaternion(),
        self.global_basis.rotated(Vector3.UP, PI).get_rotation_quaternion(),
        self.global_basis.rotated(Vector3.UP, PI * 1.5).get_rotation_quaternion(),
    ]
    quats.sort_custom(func (a: Quaternion, b: Quaternion) -> bool: return a.angle_to(global_quat) < b.angle_to(global_quat))
    return quats[0]

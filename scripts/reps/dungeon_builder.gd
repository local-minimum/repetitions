extends Node3D
class_name DungeonBuilder

@export var grid_size: Vector3
@export var player: PhysicsGridPlayerController
@export var dirt_mag: DirtMagazine

var placed_rooms: Array[Node3D]
const _BLUEPRINT_META: String = "blueprint"
const _ORIGIN_META: String = "origin"
const _COORDINATES_META: String = "coordinates"

var _dirt_offset: Vector3 = Vector3.BACK

var dirts: Dictionary[Vector3i, Node3D]
var dirt_digouts: Dictionary[Vector3i, Array]

func _enter_tree() -> void:
    if __SignalBus.on_complete_dungeon_plan.connect(_handle_complete_dungeon_plan) != OK:
        push_error("Failed to connect complete dungeon plan")
    if __SignalBus.on_use_pickax.connect(_handle_use_pickax) != OK:
        push_error("Failed to connect use pickax")
        
func _exit_tree() -> void:
    __SignalBus.on_complete_dungeon_plan.disconnect(_handle_complete_dungeon_plan)
    __SignalBus.on_use_pickax.disconnect(_handle_use_pickax)
    
func _ready() -> void:
    player.cinematic = true

func _handle_use_pickax(target: Node3D, _hack_direction: CardinalDirections.CardinalDirection, point: Vector3) -> void:
    while !target.has_meta(_COORDINATES_META):
        target = target.get_parent_node_3d()
        if target == null:
            return
    
    var coords: Vector3i = target.get_meta(_COORDINATES_META)
    if !dirts.has(coords) || dirts[coords] != target:
        push_error("%s not in known dirts %s or wrong dirt %s != %s" % [
            coords, !dirts.has(coords), dirts[coords], target,
        ])
        return
    
    var origin: Vector3 = _get_origin_corner(coords) + _dirt_offset * grid_size
    var side_points: Array[Vector3] = [
        origin + 0.5 * Vector3.RIGHT * grid_size,
        origin + 0.5 * Vector3.FORWARD * grid_size,
        origin + (Vector3.FORWARD + 0.5 * Vector3.RIGHT) * grid_size,
        origin + (0.5 * Vector3.FORWARD + Vector3.RIGHT) * grid_size,
    ]
    var side_directions: Array[CardinalDirections.CardinalDirection] = [
        CardinalDirections.CardinalDirection.SOUTH,
        CardinalDirections.CardinalDirection.WEST,
        CardinalDirections.CardinalDirection.NORTH,
        CardinalDirections.CardinalDirection.EAST,
    ]
    var closest_idx: int = -1
    var closest_dist_sq: float = -1

    for idx: int in range(4):
        var d_sq: float = point.distance_squared_to(side_points[idx])
        if closest_idx < 0 || d_sq < closest_dist_sq:
            closest_idx = idx
            closest_dist_sq = d_sq

    if closest_idx < 0:
        push_error("Failed to figure out side to dig out!")
        return
        
    var digout_direction: CardinalDirections.CardinalDirection = side_directions[closest_idx]
    _digout_coords(coords, digout_direction, target)
    var neighbour: Vector3i = CardinalDirections.translate(coords, digout_direction)
    if dirts.has(neighbour) && (!dirt_digouts.has(neighbour) || !dirt_digouts[neighbour].has(CardinalDirections.invert(digout_direction))):
        _digout_coords(neighbour, CardinalDirections.invert(digout_direction), dirts[neighbour])

func _digout_coords(coords: Vector3i, digout_direction: CardinalDirections.CardinalDirection, target: Node3D) -> void:
    var digs: Array[CardinalDirections.CardinalDirection] = []    
    if !dirt_digouts.has(coords):
        digs = [digout_direction]
        dirt_digouts[coords] = digs
    elif !dirt_digouts[coords].has(digout_direction):
        dirt_digouts[coords].append(digout_direction)
        digs = dirt_digouts[coords]
    else:
        digs = dirt_digouts[coords]
    
    print_debug("Placing new dirt at %s with digs %s" % [coords, digs.map(func (c: CardinalDirections.CardinalDirection) -> String: return CardinalDirections.name(c))])
    var new_dirt: Node3D = _place_dirt(coords, digs)
    if new_dirt != null:
        target.queue_free()
        dirts[coords] = new_dirt
    else:
        print_debug("Didn't get any new dirt!")
    
func _handle_complete_dungeon_plan(elevation: int, rooms: Array[BlueprintRoom]) -> void:
    var used_tiles: Array[Vector2i]
    var grid: Grid2D = null
    var first_room: bool = true
    var exposed_dirt: bool = false
    
    for room: BlueprintRoom in rooms:
        if room.option == null:
            push_error("Bluepint Room %s lacks an option, no clue what room to place" % room)
            continue
        
        if grid == null:
            grid = room.grid
        
        if !exposed_dirt && room.has_unused_door():
            exposed_dirt = true
                    
        var room_3d: Node3D = room.option.instantiate_3d_room()
        placed_rooms.append(room_3d)
        room_3d.set_meta(_BLUEPRINT_META, room)
        add_child(room_3d)
        
        room_3d.rotation = CardinalDirections.direction_to_rotation(
            CardinalDirections.CardinalDirection.UP, 
            room.get_rotation_direction(),
        ).get_euler()
        
        used_tiles.append_array(room.get_global_used_tiles())
        
        var origin2d: Vector2i = room.get_origin()
        var origin: Vector3i = Vector3i(origin2d.x, elevation, origin2d.y)
        
        room_3d.position = Vector3(grid_size.x * origin.x, grid_size.y * origin.y, grid_size.z * origin.z)
        room_3d.set_meta(_ORIGIN_META, origin)
        
        if first_room && player != null:
            var ppos: Vector2i = room.get_global_used_tiles()[0]
            player.global_position = to_global(Vector3((ppos.x + 0.5) * grid_size.x, elevation * grid_size.y, (ppos.y + 0.5) * grid_size.z))
            player.builder = self
            first_room = false
    
    if exposed_dirt:
        _populate_level_with_dirt(grid, elevation, used_tiles)
                    
                        
    player.cinematic = false

func _populate_level_with_dirt(grid: Grid2D, elevation: int, used_tiles: Array[Vector2i]) -> void:
    if grid != null:
        for x: int in range(grid.extent.position.x, grid.extent.end.x):
            for y: int in range(grid.extent.position.y, grid.extent.end.y):
                var coords: Vector2i = Vector2i(x, y)
                if used_tiles.has(coords):
                    continue
                    
                var coords3d: Vector3i = Vector3i(coords.x, elevation, coords.y)
                if _place_dirt(coords3d) == null:
                    push_warning("%s: Failed to place dirt at %s" % [name, coords3d])
                    
func _get_origin_corner(coords: Vector3i) -> Vector3:
    return Vector3(grid_size.x * coords.x, grid_size.y * coords.y, grid_size.z * coords.z)
    
func _place_dirt(coords: Vector3i, digs: Array[CardinalDirections.CardinalDirection] = []) -> Node3D:
    var pos: Vector3 = _get_origin_corner(coords)
    var d: Node3D = dirt_mag.place_block_at(self, pos + _dirt_offset * grid_size, grid_size, digs)
    if d != null:
        dirts[coords] = d
        d.name = "Dirt @ %s" % coords
        d.set_meta(_COORDINATES_META, coords)

    return d
        
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

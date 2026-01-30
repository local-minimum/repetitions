extends Node3D
class_name DungeonBuilder

@export var grid_size: Vector3
@export var player: PhysicsGridPlayerController
@export var dirt_mag: DirtMagazine

var placed_rooms: Array[Node3D]
const _BLUEPRINT_META: String = "blueprint"
const _ORIGIN_META: String = "origin"
const _COORDINATES_META: String = "coordinates"

var dirts: Dictionary[Vector3i, Node3D]
var dirt_digouts: Dictionary[Vector3i, Array]
var used_tiles: Array[Vector3i]

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
    player.global_position = get_closest_global_grid_position(player.global_position)
    player.builder = self

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

    var origin: Vector3 = get_global_grid_position_from_coordinates(coords)
    var side_points: Array[Vector3] = [
        origin + CardinalDirections.direction_to_vector(CardinalDirections.CardinalDirection.SOUTH) * grid_size * 0.5,
        origin + CardinalDirections.direction_to_vector(CardinalDirections.CardinalDirection.WEST) * grid_size * 0.5,
        origin + CardinalDirections.direction_to_vector(CardinalDirections.CardinalDirection.NORTH) * grid_size * 0.5,
        origin + CardinalDirections.direction_to_vector(CardinalDirections.CardinalDirection.EAST) * grid_size * 0.5,
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
    print_debug("Digging %s" % [CardinalDirections.name(digout_direction)])
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

var first_room: bool = true

func _handle_complete_dungeon_plan(elevation: int, rooms: Array[BlueprintRoom]) -> void:
    var grid: Grid2D = null
    var exposed_dirt: bool = false

    for room: BlueprintRoom in rooms:
        if room.option == null:
            push_error("Bluepint Room %s lacks an option, no clue what room to place" % room)
            continue

        if placed_rooms.any(func (pr: Node3D) -> bool: return pr.get_meta(_BLUEPRINT_META) == room):
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

        var room_tiles: Array[Vector3i] = Array(
            room.get_global_used_tiles().map(func (v2: Vector2i) -> Vector3i: return Vector3i(v2.x, elevation, v2.y)),
            TYPE_VECTOR3I,
            "",
            null,
        )

        for room_tile: Vector3i in room_tiles:
            if dirts.has(room_tile):
                dirts[room_tile].queue_free()
                if !dirts.erase(room_tile):
                    push_warning("Couldn't fully clear dirt")

                if dirt_digouts.erase(room_tile):
                    push_warning("Couldn't fully clear dirt digout data")

                # We'll readd it below, just dont want dupes
                used_tiles.erase(room_tile)

        used_tiles.append_array(room_tiles)

        var origin2d: Vector2i = room.get_origin()
        var origin: Vector3i = Vector3i(origin2d.x, elevation, origin2d.y)

        room_3d.global_position = get_global_grid_position_from_coordinates(origin)
        # print_debug("Placed room %s at %s %s with tiles %s" % [room, room_3d.position, origin, room_tiles])

        room_3d.set_meta(_ORIGIN_META, origin)

        if first_room && player != null:
            var ppos: Vector2i = room.get_global_used_tiles()[0]
            player.global_position = get_global_grid_position_from_2d_coordinates(ppos, elevation)
            first_room = false
            print_debug("Player located at %s at the center of %s" % [player.global_position, ppos])

    if exposed_dirt:
        _populate_level_with_dirt(grid, elevation)


    player.cinematic = false

func _populate_level_with_dirt(grid: Grid2D, elevation: int) -> void:
    if grid != null:
        for x: int in range(grid.extent.position.x, grid.extent.end.x):
            for y: int in range(grid.extent.position.y, grid.extent.end.y):
                var coords3d: Vector3i = Vector3i(x, elevation, y)
                if used_tiles.has(coords3d):
                    continue


                if _place_dirt(coords3d) == null:
                    push_warning("%s: Failed to place dirt at %s" % [name, coords3d])
                else:
                    used_tiles.append(coords3d)

## Get the coordinates closest to the global position
func get_closest_coordinates(global_pos: Vector3) -> Vector3i:
    var local: Vector3 = to_local(global_pos)
    return Vector3i(roundi(local.x / grid_size.x), roundi(local.y / grid_size.y), roundi(local.z / grid_size.z))

func _place_dirt(coords: Vector3i, digs: Array[CardinalDirections.CardinalDirection] = []) -> Node3D:
    var global_pos: Vector3 = get_global_grid_position_from_coordinates(coords)
    var d: Node3D = dirt_mag.place_block_at(self, global_pos, digs)
    # if coords.x == 20:
    #    print_debug("Placing dirt at %s %s" % [d.position, coords])
    if d != null:
        dirts[coords] = d
        d.name = "Dirt @ %s" % coords
        d.set_meta(_COORDINATES_META, coords)

    return d

func get_global_grid_position_from_2d_coordinates(coords: Vector2i, elevation: int) -> Vector3:
    return Vector3(coords.x * grid_size.x, elevation * grid_size.y, coords.y * grid_size.z)

func get_global_grid_position_from_coordinates(coords: Vector3i) -> Vector3:
    return Vector3(coords.x * grid_size.x, coords.y * grid_size.y, coords.z * grid_size.z)

func _get_closest_local_grid_position(global_pos: Vector3) -> Vector3:
    var local: Vector3 = to_local(global_pos)
    return Vector3(roundi(local.x / grid_size.x) * grid_size.x, roundi(local.y / grid_size.y) * grid_size.y, roundi(local.z / grid_size.z) * grid_size.z)

func get_closest_global_grid_position(global_pos: Vector3) -> Vector3:
    return to_global(_get_closest_local_grid_position(global_pos))

# Get closest neighbour to a global position in direction of the grid
func get_closest_global_neighbour_position(global_pos: Vector3, direction: CardinalDirections.CardinalDirection) -> Vector3:
    return to_global(_get_closest_local_grid_position(global_pos) + CardinalDirections.direction_to_vector(direction) * grid_size)

func get_2d_grid_float_position(global_pos: Vector3) -> Vector2:
    var pos: Vector3 = to_local(global_pos) / grid_size
    return Vector2(pos.x, pos.z)

func get_cardial_rotation(global_quat: Quaternion) -> Quaternion:
    var quats: Array[Quaternion] = [
        self.global_basis.get_rotation_quaternion(),
        self.global_basis.rotated(Vector3.UP, PI * 0.5).get_rotation_quaternion(),
        self.global_basis.rotated(Vector3.UP, PI).get_rotation_quaternion(),
        self.global_basis.rotated(Vector3.UP, PI * 1.5).get_rotation_quaternion(),
    ]
    quats.sort_custom(func (a: Quaternion, b: Quaternion) -> bool: return a.angle_to(global_quat) < b.angle_to(global_quat))
    return quats[0]

static func find_builder_in_tree(body: Node3D) -> DungeonBuilder:
    while body != null:
        if body is DungeonBuilder:
            return body as DungeonBuilder

        body = body.get_parent_node_3d()

    return null

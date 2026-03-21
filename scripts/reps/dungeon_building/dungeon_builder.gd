extends Dungeon
class_name DungeonBuilder

static var active_builder: DungeonBuilder

@export var dirt_mag: DirtMagazine

var placed_rooms: Array[Room3D]

var dirts: Dictionary[Vector3i, Node3D]
var dirt_digouts: Dictionary[Vector3i, Array]
var used_tiles: Array[Vector3i]

func _enter_tree() -> void:
    super._enter_tree()
    active_builder = self

    if __SignalBus.on_complete_dungeon_plan.connect(_handle_complete_dungeon_plan) != OK:
        push_error("Failed to connect complete dungeon plan")
    if __SignalBus.on_use_pickax.connect(_handle_use_pickax) != OK:
        push_error("Failed to connect use pickax")

func _exit_tree() -> void:
    super._exit_tree()
    if active_builder == self:
        active_builder = null
    __SignalBus.on_complete_dungeon_plan.disconnect(_handle_complete_dungeon_plan)
    __SignalBus.on_use_pickax.disconnect(_handle_use_pickax)

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

func _get_room_by_blueprint(blue_print: BlueprintRoom) -> Room3D:
    for room: Room3D in placed_rooms:
        if room.blueprint == blue_print:
            return room
    return null

static func any_door_leading_into_dirt(doors: Array[DoorData]) -> bool:
    return doors.any(func (dd: DoorData) -> bool: return dd.type == DoorData.Type.DOOR_TO_DIRT )

func _handle_complete_dungeon_plan(elevation: int, rooms: Array[BlueprintRoom]) -> void:
    var grid: Grid2D = null
    var exposed_dirt: bool = false

    for room: BlueprintRoom in rooms:
        if room.option == null:
            push_error("Bluepint Room %s lacks an option, no clue what room to place" % room)
            continue

        var room_doors: Array[DoorData] = room.all_doors
        var room3d: Room3D = _get_room_by_blueprint(room)

        if room3d != null:
            room3d.update_doors_states(room_doors)
            continue

        if grid == null:
            grid = room.grid

        if !exposed_dirt && any_door_leading_into_dirt(room_doors):
            exposed_dirt = true

        var origin2d: Vector2i = room.get_origin()
        var origin: Vector3i = Vector3i(origin2d.x, elevation, origin2d.y)

        room3d = _instantiate_3d_room(room, origin)
        room3d.configure_door_states(room_doors, placed_rooms)

        _clear_out_dirt_in_new_room(room, elevation)

        if first_room && player != null:
            var beds: Array[RestInteractable] = []
            beds.assign(room3d.find_children("", "RestInteractable"))
            if beds.is_empty():
                push_warning("Room %s does not have a bed" % [room3d])
                var ppos: Vector2i = room.get_global_used_tiles()[0]
                player.global_position = get_global_grid_position_from_2d_coordinates(ppos, elevation)
            else:
                var bed: RestInteractable = beds[0]
                player.global_position = get_global_grid_position_from_coordinates(bed.coordinates)

            player.set_rotation_away_from_wall(true)
            first_room = false
            __GlobalGameState.current_player_room = room3d
            __SignalBus.on_spawn_room_placed.emit(room3d, origin, get_closest_coordinates(player.global_position))

    if exposed_dirt:
        _populate_level_with_dirt(grid, elevation)

    player.remove_cinematic_blocker(self)

func _instantiate_3d_room(room: BlueprintRoom, origin: Vector3) -> Room3D:
    var room_3d: Room3D = room.option.instantiate_3d_room()

    room_3d.blueprint = room
    room_3d.origin = origin

    placed_rooms.append(room_3d)
    add_child(room_3d)

    room_3d.rotation = CardinalDirections.direction_to_rotation(
        CardinalDirections.CardinalDirection.UP,
        room.get_rotation_direction(),
    ).get_euler()

    room_3d.global_position = get_global_grid_position_from_coordinates(origin)
    # print_debug("Placed room %s at %s %s with tiles %s" % [room, room_3d.position, origin, room_tiles])

    return room_3d

func _clear_out_dirt_in_new_room(room: BlueprintRoom, elevation: int) -> void:
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

static func find_builder_in_tree(node: Node3D) -> DungeonBuilder:
    while node != null:
        if node is DungeonBuilder:
            return node as DungeonBuilder

        node = node.get_parent_node_3d()

    return null

@tool
extends CollisionObject2D
class_name BlueprintRoom

@export var outline: TileMapLayer
@export var doors: TileMapLayer
@export var doors_directions: TilemapDoorDirectionConfig

@export var collision: CollisionPolygon2D

@export var debug: bool
@export var placed: bool:
    set(value):
        if !Engine.is_editor_hint():
            if value:
                draggable.disable(self)
            else:
                draggable.enable(self)
        placed = value
        recalculate_collision()

var option: DraftOption

var grid: Grid2D:
    set(value):
        draggable.grid = value
        if value != null:
            assert(
                Vector2(tile_size) == value.tile_size,
                "[Blueprint Room %s] The new grid %s has a tile size of %s which doesn't line up with our internal size of %s" % [
                    name,
                    value,
                    value.tile_size,
                    tile_size,
                ],
            )
    get():
        if Engine.is_editor_hint():
            return null
        return draggable.grid

@export var draggable: Draggable

var _door_data: Array[DoorData]
var tweening: bool:
    set(value):
        if value:
            draggable.disable(self)
        elif !placed:
            draggable.enable(self)
        tweening = value

var valid_doors: Array[DoorData]:
    get():
        return _door_data.filter(
            func (ddata: DoorData) -> bool:
                return ddata.type == DoorData.Type.DOOR_TO_DOOR
        )

func has_unused_door() -> bool:
    var doors_local: Array[Vector2i] = door_local_coordinates
    var doors_global: Array[Vector2i] = draggable.translate_coords_array_to_global(self, doors_local)
    var idx: int = 0
    for lcoords: Vector2i in doors_local:
        var gcoords: Vector2i = doors_global[idx]
        var atlas: Vector2i = doors.get_cell_atlas_coords(lcoords)
        for gdir: CardinalDirections.CardinalDirection in get_global_door_directions(atlas):
            if _door_data.any(
                func (ddata: DoorData) -> bool:
                    return (
                        ddata.global_coordinates == gcoords &&
                        ddata.global_direction == gdir &&
                        ddata.room == self &&
                        ddata.type != DoorData.Type.DOOR_TO_DIRT
                    )
            ):
                continue
            return true
        idx += 1
    return false

var all_doors: Array[DoorData]:
    get():
        var ret: Array[DoorData] = []
        ret.assign(_door_data)
        var doors_local: Array[Vector2i] = door_local_coordinates
        var doors_global: Array[Vector2i] = draggable.translate_coords_array_to_global(self, doors_local)
        var idx: int = 0
        for lcoords: Vector2i in doors_local:
            var gcoords: Vector2i = doors_global[idx]
            var atlas: Vector2i = doors.get_cell_atlas_coords(lcoords)
            for gdir: CardinalDirections.CardinalDirection in get_global_door_directions(atlas):
                if _door_data.any(_create_door_filter(gcoords, gdir)):
                    continue
                ret.append(DoorData.new(DoorData.Type.DOOR_TO_DIRT, self, gcoords, gdir, null))
            idx += 1
        return ret

## Local coordinates of doors leading to nothing (not counting into walls)
var door_local_coordinates: Array[Vector2i]:
    get():
        return [] if doors == null else doors.get_used_cells()

var tile_size: Vector2i:
    get():
        if outline == null:
            return Vector2i.ONE * 64

        return outline.tile_set.tile_size

@warning_ignore_start("unused_private_class_variable")
@export_tool_button("Recalculate Collsion") var _recalc_col: Callable = recalculate_collision
@warning_ignore_restore("unused_private_class_variable")

func recalculate_collision() -> void:
    if collision == null:
        push_warning("[Blueprint Room %s] Does not have any collsion configured" % name)
        return

    collision.position = Vector2.ZERO

    if placed:
        collision.polygon = perimeter()
    else:
        var r: Rect2 = bounding_box()
        var factor: float = 0.5
        var grow_size: Vector2 = Vector2(tile_size) * factor
        r = r.grow_individual(grow_size.x, grow_size.y, grow_size.x, grow_size.y)

        collision.polygon = PackedVector2Array(RectUtils.corners(r))

var contained_in_grid: bool:
    get():
        if grid != null && grid.is_inside_grid(global_position):
            var r: Rect2i = outline.get_used_rect()
            var origin: Vector2i = get_origin()
            # We assert equal grid size so this works fine
            r.position += origin

            if grid.extent.encloses(r):
                return true
        return false

func snap_to_grid() -> void:
    if grid == null:
        push_warning("[Blueprint Room %s] Cannot snap to nothing" % name)
        return

    if contained_in_grid:
        global_position = grid.get_global_point(grid.get_closest_coordinates(global_position))

        # else:
            # print_debug("[Blueprint Room %s] I'm outside the grid: %s encloses %s = %s" % [name, grid.extent, r, grid.extent.encloses(r)])

    # else:
        # print_debug("[Blueprint Room %s] Origin outside grid" % name)

## Local space float precision bounding box, only reliable to say that things don't overlap
func bounding_box() -> Rect2:
    return RectUtils.translate(TileMapLayerUtils.bounding_box(outline), outline.position)

## Local space perimeter points
func perimeter() -> PackedVector2Array:
    return ArrayUtils.translate_packed_vector2_array(TileMapLayerUtils.perimeter(outline, true), outline.position, true)

## Logical world coordinates of room origin / what it rotates around
func get_origin() -> Vector2i:
    return draggable.calculate_coordinates(self)

func get_rotation_direction() -> CardinalDirections.CardinalDirection:
    return draggable.get_rotation(self)

## Global coordinates of all pieces of the room
func get_global_used_tiles() -> Array[Vector2i]:
    if outline == null:
        return []

    return draggable.translate_coords_array_to_global(self, outline.get_used_cells())


## Checks if global coordinates are inside the room
func is_inside(coords: Vector2i) -> bool:
    if outline == null:
        return false

    var local: Vector2i = draggable.translate_coord_to_local(self, coords)
    return outline.get_used_cells().has(local)

const OVERLAP_NONE: int = 0
const OVERLAP_TOUCH: int = 1
const OVERLAP_ONTOP: int = 2

## If two rooms overlaps
func overlaps(other: BlueprintRoom) -> int:
    var touch_margin: float = maxf(tile_size.x, tile_size.y) * 0.5 + 1.0
    # Quick test bounding boxes
    var other_bb: Rect2 = other.bounding_box().grow(touch_margin)
    # This grows slightly to ensure they aren't next to each other even
    var bb: Rect2 = bounding_box().grow(touch_margin)
    var other_bb_localized: Rect2 = RectUtils.translate_local(other_bb, other, self)

    if !bb.intersects(other_bb_localized):
        return OVERLAP_NONE

    # Extended tile check
    var other_coords: Array[Vector2i] = other.get_global_used_tiles()
    if get_global_used_tiles().any(func (c: Vector2i) -> bool: return other_coords.has(c)):
        return OVERLAP_ONTOP

    return OVERLAP_TOUCH

func get_global_door_directions(atlas_coords: Vector2i) -> Array[CardinalDirections.CardinalDirection]:
    return Array(
        doors_directions.get_directions(atlas_coords).map(
            func (d: CardinalDirections.CardinalDirection) -> CardinalDirections.CardinalDirection:
                # print_debug("!! %s oriented %s Translates direction %s to %s" % [name, draggable.get_rotation_name(self), CardinalDirections.name(d), CardinalDirections.name(draggable.get_global_direction(self, d))])
                return draggable.get_global_direction(self, d),
        ),
        TYPE_INT,
        "",
        null,
    )

func has_local_door_global_direction(local_coords: Vector2i, global_direction: CardinalDirections.CardinalDirection) -> bool:
    if doors == null || doors_directions == null:
        print_debug("[Blueprint Door %s] I have no doors..." % [name])
        return false

    var atlas_coords: Vector2i = doors.get_cell_atlas_coords(local_coords)
    var local_direction: CardinalDirections.CardinalDirection = draggable.get_local_direction(self, global_direction)
    # print_debug(doors.get_used_cells())
    # print_debug("### Room %s (%s)'s door at %s (atlas %s) check door direction %s (local %s) -> %s" % [
    #    name,
    #    draggable.get_rotation_name(self),
    #    local_coords,
    #    atlas_coords,
    #    CardinalDirections.name(global_direction),
    #    CardinalDirections.name(local_direction),
    #    doors_directions.has_door(atlas_coords, local_direction),
    #])

    if atlas_coords.x < 0 || atlas_coords.y < 0:
        return false

    return doors_directions.has_door(atlas_coords, local_direction)

func _create_door_filter(global_coords: Vector2i, global_direction: CardinalDirections.CardinalDirection) -> Callable:
    return func (ddata: DoorData) -> bool:
        return (
            ddata.room == self &&
            ddata.global_coordinates == global_coords &&
            ddata.global_direction == global_direction
        )

func has_registered_door(global_coords: Vector2i, global_direction: CardinalDirections.CardinalDirection) -> bool:
    return _door_data.any(_create_door_filter(global_coords, global_direction))

func get_connected_room(global_coords: Vector2i, global_direction: CardinalDirections.CardinalDirection) -> BlueprintRoom:
    var idx: int = _door_data.find_custom(
        func (ddata: DoorData) -> bool:
            return (
                ddata.type == DoorData.Type.DOOR_TO_DOOR &&
                ddata.room == self &&
                ddata.global_coordinates == global_coords &&
                ddata.global_direction == global_direction
            )
    )
    if idx < 0:
        return null

    return _door_data[idx].other_room

## If two rooms have doors that are connected and the door data
## The `connecting_doors` variable will contain all affected doors
## Returns true if any door coonnects
func has_connecting_doors(
    other: BlueprintRoom,
    connecting_doors: Array[DoorData],
) -> bool:
    if !connecting_doors.is_empty():
        push_warning("Expected connecting doors array to be empty, clearing it out: %s" % [connecting_doors])
        connecting_doors.clear()

    # Check doors
    var my_doors_local: Array[Vector2i] = door_local_coordinates
    var my_doors: Array[Vector2i] = draggable.translate_coords_array_to_global(self, my_doors_local)
    var other_doors_local: Array[Vector2i] = other.door_local_coordinates
    var other_doors: Array[Vector2i] = other.draggable.translate_coords_array_to_global(other, other_doors_local)

    # print_debug("%s @ %s: my doors %s and %s has %s" % [self, get_origin(), my_doors, other, other_doors])
    for my_idx: int in range(my_doors_local.size()):
        var local_coords: Vector2i = my_doors_local[my_idx]
        var atlas_coords: Vector2i = doors.get_cell_atlas_coords(local_coords)
        if !doors_directions.is_door(atlas_coords):
            push_error("[Blueprint Room %s] Has a door at %s with atlas coords %s but it isn't configured as a door in %s" % [
                name,
                local_coords,
                atlas_coords,
                doors_directions.resource_path,
            ])
            continue

        for direction: CardinalDirections.CardinalDirection in get_global_door_directions(atlas_coords):
            # print_debug("--- %s door at %s is in direction %s" % [name, my_doors[my_idx], CardinalDirections.name(direction)])
            # if has_registered_door(my_doors[my_idx], direction):
                # print_debug("%s: Already has regestered door %s with direction %s" % [self, my_doors[my_idx], CardinalDirections.name(direction)])
            #    continue

            var leading_to_coords: Vector2i = CardinalDirections.translate2d(my_doors[my_idx], direction)
            # print_debug("%s: Door %s leads %s to %s" % [self, my_doors[my_idx], CardinalDirections.name(direction), leading_to_coords])
            if other_doors.has(leading_to_coords):
                var other_idx: int = other_doors.find(leading_to_coords)
                # print_debug("%s: My door leads from %s leads to %s and Other has door %s there!" % [self, my_doors[my_idx], leading_to_coords, other_idx])
                if other.has_local_door_global_direction(other_doors_local[other_idx], CardinalDirections.invert(direction)):
                    connecting_doors.append(DoorData.new(DoorData.Type.DOOR_TO_DOOR, self, my_doors[my_idx], direction, other))
                    continue
                # else:
                #    print_debug("%s: %s has door, but it was in the wrong direction" % [self, other])
            # else:
            #    print_debug("%s: Not a door of %s %s" % [self, other, other_doors])

            if other.is_inside(leading_to_coords):
                #print_debug("%s: My door %s leads to %s which is inside %s, but not via doors!" % [self, my_doors[my_idx], leading_to_coords, other])
                connecting_doors.append(DoorData.new(DoorData.Type.DOOR_TO_WALL, self, my_doors[my_idx], direction, other))

    for other_idx: int in range(other_doors_local.size()):
        var other_local_coords: Vector2i = other_doors_local[other_idx]
        var other_atlas_coords: Vector2i = other.doors.get_cell_atlas_coords(other_local_coords)
        if !other.doors_directions.is_door(other_atlas_coords):
            push_error("[Blueprint Room %s] Has a door at %s with atlas coords %s but it isn't configured as a door in %s" % [
                other.name,
                other_local_coords,
                other_atlas_coords,
                other.doors_directions.resource_path,
            ])
            continue

        for direction: CardinalDirections.CardinalDirection in other.get_global_door_directions(other_atlas_coords):
            #if other.has_registered_door(other_doors[other_idx], direction):
            #    continue

            if connecting_doors.any(func (ddata: DoorData) -> bool: return ddata.is_inverse_connection(other, other_doors[other_idx], direction, self)):
                # We don't need a dupe
                continue

            var leading_to_coords: Vector2i = CardinalDirections.translate2d(other_doors[other_idx], direction)

            if is_inside(leading_to_coords):
                connecting_doors.append(DoorData.new(DoorData.Type.DOOR_TO_WALL, other, other_doors[other_idx], direction, self))

    # print_debug(">>> Found doors %s" % [connecting_doors])
    return connecting_doors.any(func (ddata: DoorData) -> bool: return ddata.type == DoorData.Type.DOOR_TO_DOOR)

func register_connection(data: Array[DoorData]) -> void:
    # print_debug("%s: Got door connections %s" % [self, data])
    for ddata: DoorData in data:
        if ddata.room != self && ddata.other_room != self:
            continue

        if ddata.room == self:
            var idx: int = _door_data.find_custom(_create_door_filter(ddata.global_coordinates, ddata.global_direction))
            if idx >= 0:
                _door_data[idx] = ddata
            else:
                _door_data.append(ddata)

        elif ddata.other_room == self:
            var reflected: DoorData = ddata.reflect()
            if reflected == null:
                # print_debug("Reflection of %s caused unexpected null when registering connections for %s" % [ddata, self])
                continue
            var idx: int = _door_data.find_custom(_create_door_filter(reflected.global_coordinates, reflected.global_direction))
            if idx >= 0:
                _door_data[idx] = reflected
            else:
                _door_data.append(reflected)

var _debugged: bool = true
func _draw() -> void:
    if Engine.is_editor_hint() || !debug || tweening:
        return

    var bbox: Rect2 = bounding_box()
    draw_rect(bbox, Color.MEDIUM_ORCHID, false, 1)

    if grid == null:
        return

    var origin: Vector2i = get_origin()
    for coords: Vector2i in get_global_used_tiles():
        var r: Rect2 = RectUtils.translate_local(grid.get_grid_cell_rect(coords), grid, self)
        draw_rect(
            r,
            Color.AQUA,
            origin == coords,
            1 if origin != coords else -1,
        )


    if doors != null:
        for door_coords: Vector2i in doors.get_used_cells():
            var atlas_coords: Vector2i = doors.get_cell_atlas_coords(door_coords)
            var door_global_coords: Vector2i = draggable.translate_coords_array_to_global(self, [door_coords])[0]
            var local_center: Vector2 = to_local(grid.get_global_point(door_global_coords))

            if !doors_directions.is_door(atlas_coords):
                if !_debugged:
                    print_debug("[Blueprint Room %s] Has unregistered door at atlas coords %s in %s" % [
                        name, atlas_coords, doors_directions.resource_path
                    ])

            for local_direction: CardinalDirections.CardinalDirection in doors_directions.get_directions(atlas_coords):
                if !_debugged:
                    print_debug("[Blueprint Room %s] Door at %s has atlas coords %s giving local direction %s" % [name, door_coords, atlas_coords, CardinalDirections.name(local_direction)])

                var local_delta: Vector2 = grid.tile_size * CardinalDirections.direction_to_vector2d(local_direction) * 0.5
                var global_direction: CardinalDirections.CardinalDirection = draggable.get_global_direction(self, local_direction)
                var used: bool = has_registered_door(door_global_coords, global_direction)
                var connected: bool = used && get_connected_room(door_global_coords, global_direction) != null

                var local_tip: Vector2 = local_center + local_delta * 0.8
                if !used:
                    draw_line(local_center, local_tip, Color.GREEN_YELLOW, 2)
                    draw_circle(local_tip, 2, Color.GREEN_YELLOW)
                elif connected:
                    draw_line(local_center, local_tip, Color.GREEN, 2)
                    draw_rect(Rect2(local_center, Vector2.ZERO).grow(2), Color.GREEN)
                else:
                    draw_line(local_center, local_tip, Color.DARK_RED, 2)
                    # NOTE: If the grid is not square this isn't fully correct
                    var rotated_delta: Vector2 = grid.tile_size * CardinalDirections.direction_to_vector2d(CardinalDirections.yaw_cw(local_direction)[0]) * 0.5
                    draw_line(local_tip - rotated_delta * 0.6, local_tip + rotated_delta * 0.6, Color.DARK_RED, 2)

    _debugged = true

func _enter_tree() -> void:
    if Engine.is_editor_hint():
        return

    if !mouse_entered.is_connected(_handle_mouse_enter) && mouse_entered.connect(_handle_mouse_enter) != OK:
        push_error("Failed to connect mouse enter")
    if !mouse_exited.is_connected(_handle_mouse_exit) && mouse_exited.connect(_handle_mouse_exit) != OK:
        push_error("Failed to connect mouse exit")
    if !input_event.is_connected(_handle_input_event) && input_event.connect(_handle_input_event) != OK:
        push_error("Failed to connect input event")

    if draggable != null:
        if draggable.on_grid_drag_end.connect(_handle_grid_drag_end) != OK:
            push_error("Failed to connect grid drag end")
        if draggable.on_rotation_start.connect(_handle_rotation_start) != OK:
            push_error("Failed to connect rotation start")
        if draggable.on_rotation_end.connect(_handle_rotation_end) != OK:
            push_error("Failed to connect rotation end")
        if draggable.on_grid_drag_change.connect(_handle_grid_drag_change) != OK:
            push_error("Failed to connect grid drag change")
        if draggable.on_grid_drag_start.connect(_handle_drag_start) != OK:
            push_error("Failed to connect drag start")


func _exit_tree() -> void:
    if Engine.is_editor_hint():
        return

    mouse_entered.disconnect(_handle_mouse_enter)
    mouse_exited.disconnect(_handle_mouse_exit)
    input_event.disconnect(_handle_input_event)

    if draggable != null:
        draggable.on_grid_drag_start.disconnect(_handle_drag_start)
        draggable.on_grid_drag_end.disconnect(_handle_grid_drag_end)
        draggable.on_rotation_start.disconnect(_handle_rotation_start)
        draggable.on_rotation_end.disconnect(_handle_rotation_end)
        draggable.on_grid_drag_change.disconnect(_handle_grid_drag_change)

func _ready() -> void:
    if Engine.is_editor_hint():
        return

    if placed:
        draggable.disable(self)
    else:
        draggable.enable(self)

func _handle_grid_drag_change(node: Node2D, valid: bool, coordinates: Vector2i) -> void:
    if node != self:
        return

    __SignalBus.on_blueprint_room_position_updated.emit(self, coordinates, valid)

var _being_dragged: bool = false

func _handle_drag_start(node: Node2D) -> void:
    if node != self:
        return

    _being_dragged = true
    __SignalBus.on_blueprint_room_move_start.emit(self)

func _handle_rotation_start(node: Node2D) -> void:
    if node != self || _being_dragged:
        return
    __SignalBus.on_blueprint_room_move_start.emit(self)

func _handle_rotation_end(node: Node2D, start_angle: float) -> void:
    if node != self:
        return

    if grid != null:
        __SignalBus.on_blueprint_room_position_updated.emit(
            self,
            grid.get_closest_coordinates(global_position),
            grid.is_inside_grid(global_position),
        )

    if !_being_dragged:
        __SignalBus.on_blueprint_room_dropped.emit(self, global_position, start_angle)

func _handle_grid_drag_end(
    node: Node2D,
    start_point: Vector2,
    start_angle: float,
    _from: Vector2i,
    _from_valid: bool,
    _to: Vector2i,
    _to_valid: bool,
) -> void:
    if node != self:
        return
    _being_dragged = false
    __SignalBus.on_blueprint_room_dropped.emit(self, start_point, start_angle)

func _handle_mouse_enter() -> void:
    draggable.handle_mouse_enter(self)
    __SignalBus.on_hover_blueprint_room_enter.emit(self)

func _handle_mouse_exit() -> void:
    draggable.handle_mouse_exit(self)
    __SignalBus.on_hover_blueprint_room_exit.emit(self)

func _handle_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
    if !draggable.dragging(self) && placed:
        return
    draggable.handle_input_event(self, event)

func _unhandled_input(event: InputEvent) -> void:
    draggable.unhandled_input(self, event)

func _process(_delta: float) -> void:
    if debug:
        queue_redraw()

func summary() -> String:
    return "<Room %s: %s @ %s %s with doors %s>" % [
        name,
        "placed" if placed else "unplaced",
        get_origin(),
        draggable.get_rotation_name(self),
        _door_data,
    ]

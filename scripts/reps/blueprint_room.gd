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
        if value:
            draggable.enable(self)
        else:
            draggable.disable(self)
        placed = value
        
var grid: Grid2D:
    set(value):
        draggable.grid = value
        if value != null && !VectorUtils.is_scaled2di(tile_size, value.tile_size):
            push_warning("[Blueprint Room %s] The new grid %s has a tile size of %s which doesn't line up with our internal size of %s" % [
                value,
                value.tile_size,
                tile_size,
            ])
    get():
        return draggable.grid

@export var draggable: Draggable

var _door_data: Array[DoorData]

## Local coordinates of connected doors (valids)
var connected_doors: Array[DoorData]:
    get():
        return _door_data.filter(func (ddata: DoorData) -> bool: return ddata.valid)
         
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
        
    collision.polygon = perimeter()
    
## Local space float precision bounding box, only reliable to say that things don't overlap
func bounding_box() -> Rect2: 
    return TileMapLayerUtils.bounding_box(outline)

## Local space perimeter points
func perimeter() -> PackedVector2Array:
    return TileMapLayerUtils.perimeter(outline)
    
## Logical world coordinates of room origin / what it rotates around
func get_origin() -> Vector2i:
    return draggable.calculate_coordinates(self)

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
    # Quick test bounding boxes
    var other_bb: Rect2 = other.bounding_box()
    # This grows slightly to ensure they aren't next to each other even 
    var bb: Rect2 = bounding_box().grow(0.5) 
    var other_bb_localized: Rect2 = transform * (other.global_transform.affine_inverse() * other_bb)  
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
                return draggable.get_global_direction(self, d),
        ), 
        TYPE_INT, 
        "", 
        null,
    )

func has_door_global_direction(global_coords: Vector2i, global_direction: CardinalDirections.CardinalDirection) -> bool:
    if doors == null || doors_directions == null:
        return false
        
    var atlas_coords: Vector2i = doors.get_cell_atlas_coords(global_coords)
    return doors_directions.has_door(atlas_coords, draggable.get_local_direction(self, global_direction))  

func has_registered_door(global_coords: Vector2i, global_direction: CardinalDirections.CardinalDirection) -> bool:
    return _door_data.any(func (ddata: DoorData) -> bool: return ddata.room == self && ddata.global_coordinates == global_coords && ddata.global_direction == global_direction)

func get_connected_room(global_coords: Vector2i, global_direction: CardinalDirections.CardinalDirection) -> BlueprintRoom:
    var idx: int = _door_data.find(func (ddata: DoorData) -> bool: return ddata.valid && ddata.room == self && ddata.global_coordinates == global_coords && ddata.global_direction == global_direction)
    if idx < 0:
        return null
    
    return _door_data[idx].other_room
                
## If two rooms have doors that are connected and the door data
## The `connecting_doors` variable will contain all affected doors
## Returns true as soon as any door coonnects
func has_connecting_doors(
    other: BlueprintRoom, 
    connecting_doors: Array[DoorData],
) -> bool:
    connecting_doors.clear()
    
    # Check doors
    var my_doors_local: Array[Vector2i] = door_local_coordinates
    var my_doors: Array[Vector2i] = draggable.translate_coords_array_to_global(self, my_doors_local)
    var other_doors_local: Array[Vector2i] = other.door_local_coordinates
    var other_doors: Array[Vector2i] = other.draggable.translate_coords_array_to_global(other, other_doors_local)
    
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
            if has_registered_door(my_doors[my_idx], direction):
                continue
                
            var leading_to_coords: Vector2i = CardinalDirections.translate2d(my_doors[my_idx], direction)
            if other_doors.has(leading_to_coords):
                var other_idx: int = other_doors.find(leading_to_coords)

                if other.has_door_global_direction(other_doors_local[other_idx], CardinalDirections.invert(direction)):
                    connected_doors.append(DoorData.new(true, self, my_doors[my_idx], direction, other))              
                    continue
                    
            if other.is_inside(leading_to_coords):
                connected_doors.append(DoorData.new(false, self, my_doors[my_idx], direction, other))
    
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
        
        for direction: CardinalDirections.CardinalDirection in other.get_global_door_directions(other_atlas_coords):
            if other.has_registered_door(other_doors[other_idx], direction):
                continue
                
            if connected_doors.any(func (ddata: DoorData) -> bool: return ddata.is_inverse_connection(other, other_doors[other_idx], direction, self)):
                # We don't need a dupe
                continue
            
            var leading_to_coords: Vector2i = CardinalDirections.translate2d(other_doors[other_idx], direction)
            
            if is_inside(leading_to_coords):
                connected_doors.append(DoorData.new(false, other, other_doors[other_idx], direction, self))
                
    return connecting_doors.any(func (ddata: DoorData) -> bool: return ddata.valid)

func register_connection(data: Array[DoorData]) -> void:
    for ddata: DoorData in data:
        if ddata.room != self && ddata.other_room != self:
            continue
        
        if ddata.room == self:
            if has_registered_door(ddata.global_coordinates, ddata.global_direction):
                continue
            _door_data.append(ddata)
            
        elif ddata.other_room == self:
            var reflected: DoorData = ddata.reflect()
            if has_registered_door(reflected.global_coordinates, reflected.global_direction):
                continue
                
            _door_data.append(reflected)

var _debugged: bool = true
func _draw() -> void:
    if Engine.is_editor_hint():
        return
        
    var bbox: Rect2 = bounding_box()
    draw_rect(bbox, Color.MEDIUM_ORCHID, false, 1)
    
    if outline != null:
        for tile_coords: Vector2i in outline.get_used_cells():
            draw_rect(TileMapLayerUtils.get_tile_bbox(outline, tile_coords), Color.AQUA, false, 1)
    
    if doors != null:
        for door_coords: Vector2i in doors.get_used_cells():
            var atlas_coords: Vector2i = doors.get_cell_atlas_coords(door_coords)
            var tile_bbox: Rect2 = TileMapLayerUtils.get_tile_bbox(doors, door_coords)
            var door_global_coords: Vector2i = draggable.translate_coords_array_to_global(self, [door_coords])[0]
            var center: Vector2 = tile_bbox.get_center()
            
            if !doors_directions.is_door(atlas_coords):
                if !_debugged:
                    print_debug("[Blueprint Room %s] Has unregistered door at atlas coords %s in %s" % [
                        name, atlas_coords, doors_directions.resource_path
                    ])
            for local_direction: CardinalDirections.CardinalDirection in doors_directions.get_directions(atlas_coords):
                if !_debugged:
                    print_debug("[Blueprint Room %s] Door at %s has atlas coords %s giving local direction %s" % [name, door_coords, atlas_coords, CardinalDirections.name(local_direction)])
                    
                var delta: Vector2 = tile_bbox.size * CardinalDirections.direction_to_vector2d(local_direction) * 0.5
                var direction: CardinalDirections.CardinalDirection = draggable.get_global_direction(self, local_direction)
                var used: bool = has_registered_door(door_global_coords, direction)
                var connected: bool = used && get_connected_room(door_global_coords, direction) != null
                var tip: Vector2 = center + delta * 0.8
                if !used:              
                    draw_line(center, tip, Color.GREEN_YELLOW, 2)
                    draw_circle(tip, 2, Color.GREEN_YELLOW)
                elif connected:
                    draw_line(center, tip, Color.GREEN, 2)
                    draw_rect(Rect2(center, Vector2.ZERO).grow(2), Color.GREEN)
                else:
                    draw_line(center, tip, Color.DARK_RED, 2)
                    var rotated_delta: Vector2 = tile_bbox.size * CardinalDirections.direction_to_vector2d(CardinalDirections.yaw_cw(local_direction)[0]) * 0.5
                    draw_line(tip - rotated_delta * 0.6, tip + rotated_delta * 0.6, Color.DARK_RED, 2)
                
    _debugged = true

func _enter_tree() -> void:
    if !mouse_entered.is_connected(_handle_mouse_enter) && mouse_entered.connect(_handle_mouse_enter) != OK:
        push_error("Failed to connect mouse enter")
    if !mouse_exited.is_connected(_handle_mouse_exit) && mouse_exited.connect(_handle_mouse_exit) != OK:
        push_error("Failed to connect mouse exit")
    if !input_event.is_connected(_handle_input_event) && input_event.connect(_handle_input_event) != OK:
        push_error("Failed to connect input event")
        
func _exit_tree() -> void:
    mouse_entered.disconnect(_handle_mouse_enter)
    mouse_exited.disconnect(_handle_mouse_exit)
    input_event.disconnect(_handle_input_event)
    
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
    if debug && !draggable.rotating:
        queue_redraw()

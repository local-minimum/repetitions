extends Node2D
class_name BlueprintRoom

@export var outline: TileMapLayer
@export var doors: TileMapLayer
@export var doors_directions: TilemapDoorDirectionConfig
@export var debug: bool

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

## Local space float precision bounding box, only reliable to say that things don't overlap
func bounding_box() -> Rect2:
    var size: Vector2i = tile_size
    var local_logical_rect: Rect2i = outline.get_used_rect() if outline != null else Rect2i()
    return Rect2(local_logical_rect.position * size, local_logical_rect.size * size)

## Logical world coordinates of room origin / what it rotates around
func get_origin() -> Vector2i:
    var size: Vector2i = tile_size
    return Vector2i(floori(global_position.x / size.x), floori(global_position.y / size.y))
    
const DIR_NORTH: int = 0
const DIR_WEST: int = 1
const DIR_SOUTH: int = 2
const DIR_EAST: int = 3

## Global coordinates of all pieces of the room
func get_global_used_tiles() -> Array[Vector2i]:
    if outline == null:
        return []

    return _translate_coords_to_global(outline.get_used_cells())

func _get_rotation_direction() -> int:
    var dir: float = global_transform.get_rotation() / (0.5 * PI)
    var diri: int = roundi(dir)
    if abs(dir - diri) > 0.01:
        push_error("[Blueprint Room %s] Has global rotation %s, expected to follow a cardinal" % [name, global_transform.get_rotation()])

    return posmod(diri, 4)       
        
func _translate_coords_to_global(coords: Array[Vector2i]) -> Array[Vector2i]:
    var origin: Vector2i = get_origin()
    var res: Array[Vector2i]

    match _get_rotation_direction():
        DIR_NORTH:
            res.append_array(coords)
        DIR_WEST:
            res.append_array(coords.map(func (c: Vector2i) -> Vector2i: return Vector2i(-c.y, c.x)))
        DIR_SOUTH:
            res.append_array(coords.map(func (c: Vector2i) -> Vector2i: return Vector2i(-c.x, -c.x)))   
        DIR_EAST:
            res.append_array(coords.map(func (c: Vector2i) -> Vector2i: return Vector2i(c.y, -c.x)))
             
    return Array(res.map(func (c: Vector2i) -> Vector2i: return c + origin), TYPE_VECTOR2I, "", null)

func _translate_coord_to_local(coords: Vector2i) -> Vector2i:
    var origin: Vector2i = get_origin()
    coords -= origin
    
    match _get_rotation_direction():
        DIR_NORTH:
            return coords
        DIR_SOUTH:
            return Vector2i(-coords.x, -coords.y)
        DIR_WEST:
            return Vector2i(coords.y, -coords.x)
        DIR_EAST:
            return Vector2i(-coords.y, coords.x)
        _:
            return coords
    
## Checks if global coordinates are inside the room  
func is_inside(coords: Vector2i) -> bool:
    if outline == null:
        return false
        
    var local: Vector2i = _translate_coord_to_local(coords)
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

class DoorData:
    var valid: bool
    var room: BlueprintRoom
    var global_coordinates: Vector2i
    var global_direction: CardinalDirections.CardinalDirection
    var other_room: BlueprintRoom
    
    @warning_ignore_start("shadowed_variable")
    func _init(
        valid: bool, 
        room: BlueprintRoom, 
        global_coordinates: Vector2i, 
        global_direction: CardinalDirections.CardinalDirection, 
        other_room: BlueprintRoom,
    ) -> void:
        @warning_ignore_restore("shadowed_variable")
        self.valid = valid
        self.room = room
        self.global_coordinates = global_coordinates
        self.global_direction = global_direction
        self.other_room = other_room
    
    @warning_ignore_start("shadowed_variable")
    func is_inverse_connection(
        room: BlueprintRoom, 
        global_coordinates: Vector2i, 
        global_direction: CardinalDirections.CardinalDirection, 
        other_room: BlueprintRoom,        
    ) -> bool:
        @warning_ignore_restore("shadowed_variable")
        return (
            self.room == other_room && 
            self.other_room == room && 
            CardinalDirections.translate2d(global_coordinates, global_direction) == self.global_coordinates &&
            CardinalDirections.invert(global_direction) == self.global_direction
        )
    
    func reflect() -> DoorData:
        return DoorData.new(valid, other_room, CardinalDirections.translate2d(global_coordinates, global_direction), CardinalDirections.invert(global_direction), room)

func _get_rotated_direction(local_direction: CardinalDirections.CardinalDirection) -> CardinalDirections.CardinalDirection:
    match _get_rotation_direction():
        DIR_NORTH:
            return local_direction
        DIR_SOUTH:
            return CardinalDirections.invert(local_direction)
        DIR_WEST:
            return CardinalDirections.yaw_ccw(local_direction)[0]
        DIR_EAST:
            return CardinalDirections.yaw_cw(local_direction)[0]
        _:
            return local_direction     
 
func _get_local_direction(global_direction: CardinalDirections.CardinalDirection) -> CardinalDirections.CardinalDirection:
     match _get_rotation_direction():
        DIR_NORTH:
            return global_direction
        DIR_SOUTH:
            return CardinalDirections.invert(global_direction)
        DIR_WEST:
            return CardinalDirections.yaw_cw(global_direction)[0]
        DIR_EAST:
            return CardinalDirections.yaw_ccw(global_direction)[0]
        _:
            return global_direction 
              
func get_global_door_directions(atlas_coords: Vector2i) -> Array[CardinalDirections.CardinalDirection]:
    return Array(doors_directions.get_directions(atlas_coords).map(_get_rotated_direction), TYPE_INT, "", null)

func has_door_global_direction(global_coords: Vector2i, global_direction: CardinalDirections.CardinalDirection) -> bool:
    if doors == null || doors_directions == null:
        return false
        
    var atlas_coords: Vector2i = doors.get_cell_atlas_coords(global_coords)
    return doors_directions.has_door(atlas_coords, _get_local_direction(global_direction))  

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
    var my_doors: Array[Vector2i] = _translate_coords_to_global(my_doors_local)
    var other_doors_local: Array[Vector2i] = other.door_local_coordinates
    var other_doors: Array[Vector2i] = other._translate_coords_to_global(other_doors_local)
    
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
            
## Local space bounding box
func _get_tile_bbox(local_coords: Vector2i) -> Rect2:
    var tsize: Vector2 = tile_size
    return Rect2(Vector2(tsize.x * local_coords.x, tsize.y * local_coords.y), tsize)

var _debugged: bool
func _draw() -> void:
    var bbox: Rect2 = bounding_box()
    draw_rect(bbox, Color.MEDIUM_ORCHID, false, 1)
    
    if outline != null:
        for tile_coords: Vector2i in outline.get_used_cells():
            draw_rect(_get_tile_bbox(tile_coords), Color.AQUA, false, 1)
    
    if doors != null:
        for door_coords: Vector2i in doors.get_used_cells():
            var atlas_coords: Vector2i = doors.get_cell_atlas_coords(door_coords)
            var tile_bbox: Rect2 = _get_tile_bbox(door_coords)
            var door_global_coords: Vector2i = _translate_coords_to_global([door_coords])[0]
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
                var direction: CardinalDirections.CardinalDirection = _get_rotated_direction(local_direction)
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
func _process(_delta: float) -> void:
    if debug:
        queue_redraw()

extends Node2D
class_name BlueprintRoom

@export var outline: TileMapLayer
@export var doors: TileMapLayer
@export var doors_directions: TilemapDoorDirectionConfig

var connected_doors: Array[Vector2i]
var unconnected_doors: Array[Vector2i]:
    get():
        return [] if doors == null else doors.get_used_cells().filter(func (c: Vector2i) -> bool: return !connected_doors.has(c))
        
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
             
    return res.map(func (c: Vector2i) -> Vector2i: return c + origin)

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
    var direction: CardinalDirections.CardinalDirection
    var other_room: BlueprintRoom
    
    @warning_ignore_start("shadowed_variable")
    func _init(
        valid: bool, 
        room: BlueprintRoom, 
        global_coordinates: Vector2i, 
        direction: CardinalDirections.CardinalDirection, 
        other_room: BlueprintRoom,
    ) -> void:
        @warning_ignore_restore("shadowed_variable")
        self.valid = valid
        self.room = room
        self.global_coordinates = global_coordinates
        self.direction = direction
        self.other_room = other_room
    
    @warning_ignore_start("shadowed_variable")
    func is_inverse_connection(
        room: BlueprintRoom, 
        global_coordinates: Vector2i, 
        direction: CardinalDirections.CardinalDirection, 
        other_room: BlueprintRoom,        
    ) -> bool:
        @warning_ignore_restore("shadowed_variable")
        return (
            self.room == other_room && 
            self.other_room == room && 
            CardinalDirections.translate2d(global_coordinates, direction) == self.global_coordinates
        )
    
## If two rooms have doors that are connected and the door data
## The `connecting_doors` variable will contain all affected doors
## Returns true as soon as any door coonnects
func has_connecting_doors(
    other: BlueprintRoom, 
    connecting_doors: Array[DoorData],
) -> bool:
    connecting_doors.clear()
    
    # Check doors
    var my_doors_local: Array[Vector2i] = unconnected_doors
    var my_doors: Array[Vector2i] = _translate_coords_to_global(my_doors_local)
    var other_doors_local: Array[Vector2i] = other.unconnected_doors
    var other_doors: Array[Vector2i] = other._translate_coords_to_global(other_doors_local)
    
    for my_idx: int in range(my_doors_local.size()):
        var local_coords: Vector2i = my_doors_local[my_idx]
        var id: int = doors.get_cell_source_id(local_coords)
        if !doors_directions.is_door(id):
            push_error("[Blueprint Room %s] Has a door at %s with id %s but it isn't configured as a door in %s" % [
                name,
                local_coords,
                id,
                doors_directions.resource_path,
            ])
            continue
        
        for direction: CardinalDirections.CardinalDirection in doors_directions.get_directions(id):
            var leading_to_coords: Vector2i = CardinalDirections.translate2d(my_doors[my_idx], direction)
            if other_doors.has(leading_to_coords):
                var other_idx: int = other_doors.find(leading_to_coords)
                var other_id: int = other.doors.get_cell_source_id(other_doors_local[other_idx])
                if other.doors_directions.has_door(other_id, CardinalDirections.invert(direction)):
                    connected_doors.append(DoorData.new(true, self, my_doors[my_idx], direction, other))              
                    continue
                    
            if other.is_inside(leading_to_coords):
                connected_doors.append(DoorData.new(false, self, my_doors[my_idx], direction, other))
    
    for other_idx: int in range(other_doors_local.size()):
        var other_local_coords: Vector2i = other_doors_local[other_idx]
        var other_id: int = other.doors.get_cell_source_id(other_local_coords)
        if !other.doors_directions.is_door(other_id):
            push_error("[Blueprint Room %s] Has a door at %s with id %s but it isn't configured as a door in %s" % [
                other.name,
                other_local_coords,
                other_id,
                other.doors_directions.resource_path,
            ])
        
        for direction: CardinalDirections.CardinalDirection in other.doors_directions.get_directions(other_id):
            if connected_doors.any(func (ddata: DoorData) -> bool: return ddata.is_inverse_connection(other, other_doors[other_idx], direction, self)):
                # We don't need a dupe
                continue
            
            var leading_to_coords: Vector2i = CardinalDirections.translate2d(other_doors[other_idx], direction)
            
            if is_inside(leading_to_coords):
                connected_doors.append(DoorData.new(false, other, other_doors[other_idx], direction, self))
                
    return connecting_doors.any(func (ddata: DoorData) -> bool: return ddata.valid)

func register_connection(data: Array[DoorData]) -> void:
    for ddata: DoorData in data:
        # TODO: Pass
        pass

extends Node2D
class_name BlueprintRoom

@export var outline: TileMapLayer
@export var doors: TileMapLayer


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
    
func _translate_coords_to_global(coords: Array[Vector2i]) -> Array[Vector2i]:
    var origin: Vector2i = get_origin()
    var res: Array[Vector2i]
    var dir: float = global_transform.get_rotation() / (0.5 * PI)
    var diri: int = roundi(dir)
    if abs(dir - diri) > 0.01:
        push_error("[Blueprint Room %s] Has global rotation %s, expected to follow a cardinal" % [name, global_transform.get_rotation()])

    diri = posmod(diri, 4)
    match diri:
        DIR_NORTH:
            res.append_array(coords)
        DIR_WEST:
            res.append_array(coords.map(func (c: Vector2i) -> Vector2i: return Vector2i(-c.y, c.x)))
        DIR_SOUTH:
            res.append_array(coords.map(func (c: Vector2i) -> Vector2i: return Vector2i(-c.x, -c.x)))   
        DIR_EAST:
            res.append_array(coords.map(func (c: Vector2i) -> Vector2i: return Vector2i(c.y, -c.x)))
             
    return res.map(func (c: Vector2i) -> Vector2i: return c + origin)  

## If two rooms overlaps
func overlaps(other: BlueprintRoom) -> bool:
    # Quick test bounding boxes
    var other_bb: Rect2 = other.bounding_box()
    var bb: Rect2 = bounding_box()
    var other_bb_localized: Rect2 = transform * (other.global_transform.affine_inverse() * other_bb)  
    if !bb.intersects(other_bb_localized):
        return false
    
    # Extended tile check
    var other_coords: Array[Vector2i] = other.get_global_used_tiles()
    return get_global_used_tiles().any(func (c: Vector2i) -> bool: return other_coords.has(c))    

class DoorData:
    var valid: bool
    var room: BlueprintRoom
    var coordinates: Vector2i
    var direction: CardinalDirections.CardinalDirection
    
## If two rooms have doors that are connected and the door data
func connecting_doors(other: BlueprintRoom, doors: Array[DoorData]) -> bool:
    doors.clear()

    if other.doors == null || doors == null:
        return false

    return false

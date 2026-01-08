extends Resource
class_name TilemapDoorDirectionConfig

@export var _north: Array[Vector2i]
@export var _south: Array[Vector2i]
@export var _west: Array[Vector2i]
@export var _east: Array[Vector2i]

func is_door(atlas_coords: Vector2i) -> bool:
    return _north.has(atlas_coords) || _south.has(atlas_coords) || _west.has(atlas_coords) || _east.has(atlas_coords)

func has_door(atlas_coords: Vector2i, direction: CardinalDirections.CardinalDirection) -> bool:
    match direction:
        CardinalDirections.CardinalDirection.NORTH:
            return _north.has(atlas_coords)
        CardinalDirections.CardinalDirection.SOUTH:
            return _south.has(atlas_coords)
        CardinalDirections.CardinalDirection.WEST:
            return _west.has(atlas_coords)
        CardinalDirections.CardinalDirection.EAST:
            return _east.has(atlas_coords)
        _:
            push_warning("It is not possible to have a door in %s direction" % CardinalDirections.name(direction))
            print_stack()
            return false

func get_directions(atlas_coords: Vector2i) -> Array[CardinalDirections.CardinalDirection]:
    var ret: Array[CardinalDirections.CardinalDirection]
    
    if _north.has(atlas_coords):
        ret.append(CardinalDirections.CardinalDirection.NORTH)
    if _south.has(atlas_coords):
        ret.append(CardinalDirections.CardinalDirection.SOUTH)
    if _west.has(atlas_coords):
        ret.append(CardinalDirections.CardinalDirection.WEST)
    if _east.has(atlas_coords):
        ret.append(CardinalDirections.CardinalDirection.EAST)
        
    return ret

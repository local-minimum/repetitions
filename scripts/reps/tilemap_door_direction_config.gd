extends Resource
class_name TilemapDoorDirectionConfig

@export var _north: PackedInt32Array
@export var _south: PackedInt32Array
@export var _west: PackedInt32Array
@export var _east: PackedInt32Array

func is_door(id: int) -> bool:
    return _north.has(id) || _south.has(id) || _west.has(id) || _east.has(id)

func has_door(id: int, direction: CardinalDirections.CardinalDirection) -> bool:
    match direction:
        CardinalDirections.CardinalDirection.NORTH:
            return _north.has(id)
        CardinalDirections.CardinalDirection.SOUTH:
            return _south.has(id)
        CardinalDirections.CardinalDirection.WEST:
            return _west.has(id)
        CardinalDirections.CardinalDirection.EAST:
            return _east.has(id)
        _:
            push_warning("It is not possible to have a door in %s direction" % CardinalDirections.name(direction))
            print_stack()
            return false

func get_directions(id: int) -> Array[CardinalDirections.CardinalDirection]:
    var ret: Array[CardinalDirections.CardinalDirection]
    
    if _north.has(id):
        ret.append(CardinalDirections.CardinalDirection.NORTH)
    if _south.has(id):
        ret.append(CardinalDirections.CardinalDirection.SOUTH)
    if _west.has(id):
        ret.append(CardinalDirections.CardinalDirection.WEST)
    if _east.has(id):
        ret.append(CardinalDirections.CardinalDirection.EAST)
        
    return ret

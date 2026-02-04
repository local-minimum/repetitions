class_name DoorData

enum Type { UNKNOWN, DOOR_TO_DOOR, DOOR_TO_WALL, DOOR_TO_DIRT }

## If the door is paired with another room's door
var type: Type
var room: BlueprintRoom
var global_coordinates: Vector2i
var global_direction: CardinalDirections.CardinalDirection
var other_room: BlueprintRoom

var other_global_coordinates: Vector2i:
    get():
        return CardinalDirections.translate2d(global_coordinates, global_direction)

@warning_ignore_start("shadowed_variable")
func _init(
    type: Type,
    room: BlueprintRoom,
    global_coordinates: Vector2i,
    global_direction: CardinalDirections.CardinalDirection,
    other_room: BlueprintRoom,
) -> void:
    @warning_ignore_restore("shadowed_variable")
    self.type = type
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
        other_global_coordinates == self.global_coordinates &&
        CardinalDirections.invert(global_direction) == self.global_direction
    )

func reflect() -> DoorData:
    match type:
        Type.DOOR_TO_DOOR:
            return DoorData.new(type, other_room, other_global_coordinates, CardinalDirections.invert(global_direction), room)
        _:
            push_error("There's no valid reflection on a door data of type %s %s" % [Type.find_key(type), self])
            return null

func _to_string() -> String:
    match type:
        Type.DOOR_TO_DOOR:
            if room == null || other_room == null:
                return _corrupted_info()
            return "<DoorData: %s->%s @ %s %s>" % [
                room.name,
                other_room.name,
                global_coordinates,
                CardinalDirections.name(global_direction)
            ]

        Type.DOOR_TO_WALL:
            if room == null || other_room == null:
                return _corrupted_info()
            return "<DoorData: %s->%s[WALL] @ %s %s>" % [
                room.name,
                other_room.name,
                global_coordinates,
                CardinalDirections.name(global_direction)
            ]

        Type.DOOR_TO_DIRT:
            if room == null || other_room != null:
                return _corrupted_info()
            return "<DoorData: %s->[DIRT] @ %s %s>" % [
                room.name,
                global_coordinates,
                CardinalDirections.name(global_direction)
            ]

        Type.UNKNOWN:
            return _corrupted_info()

        _:
            push_warning("Unhandled type on %s" % [_corrupted_info()])
            return _corrupted_info()

func _corrupted_info() -> String:
    return "<DoorData CORRUPTED: %s->%s @ %s %s as %s>" % [room, other_room, global_coordinates, CardinalDirections.name(global_direction), Type.find_key(type)]

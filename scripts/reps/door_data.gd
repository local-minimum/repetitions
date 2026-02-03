class_name DoorData

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

func _to_string() -> String:
    if valid && room != null && other_room != null:
        return "<DoorData: %s->%s @ %s %s>" % [room.name, other_room.name, global_coordinates, CardinalDirections.name(global_direction)]
    elif !valid && room != null && other_room != null:
        return "<DoorData: %s->%s[WALL] @ %s %s>" % [room.name, other_room.name, global_coordinates, CardinalDirections.name(global_direction)]

    return "<DoorData CORRUPTED: %s->%s @ %s %s as %s>" % [room, other_room, global_coordinates, CardinalDirections.name(global_direction), "valid" if valid else "invalid"]

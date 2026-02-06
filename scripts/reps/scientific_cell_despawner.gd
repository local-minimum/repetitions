extends ConnectionReaction

@export var _despawn_if_blueprint: DraftOption
@export var _despawns: Array[Node]

const _OVERRIDE_BOOL_META: String = "special_science_cell_connection"

func handle_connection(other_room: Room3D, other_door: DoorConfigurationOptions) -> void:
    if (
        other_room.blueprint.option == _despawn_if_blueprint &&
        (other_door != null && !other_door.get_meta(_OVERRIDE_BOOL_META, false))
    ):
        for despawn: Node in _despawns:
            despawn.queue_free()

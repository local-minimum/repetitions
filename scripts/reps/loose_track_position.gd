extends Node3D
class_name LooseTrackPosition

@export var _door: DoorConfigurationOptions

var allowed: bool
var occupied: bool

func _enter_tree() -> void:
    if (
        _door != null &&
        _door.on_connect_doors.connect(_handle_connect_doors) != OK
    ):
        push_error("Failed to connect connect doors")

func _handle_connect_doors(
    own_state: DoorConfigurationOptions.DoorState,
    other_state: DoorConfigurationOptions.DoorState,
    own_special: DoorConfigurationOptions.SpecialState,
    other_special: DoorConfigurationOptions.SpecialState,
) -> void:
    allowed = (
        own_state == DoorConfigurationOptions.DoorState.NO_DOOR &&
        other_state == DoorConfigurationOptions.DoorState.NO_DOOR &&
        own_special == DoorConfigurationOptions.SpecialState.NONE &&
        other_special == DoorConfigurationOptions.SpecialState.NONE
    )

static func find_in_tree(node: Node) -> LooseTrackPosition:
    if node == null:
        return null

    if node is LooseTrackPosition:
        return node

    print_debug("%s not a loose track position" % [node])
    return find_in_tree(node.get_parent())

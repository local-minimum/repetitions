extends Node3D
class_name DoorConfigurationOptions

var finalized: bool
var _current_data: DoorData

func resolve_connected_doors(data: DoorData, _other: Room3D) -> void:
    if finalized || data == _current_data:
        return

func resolve_door_to_wall(data: DoorData, _other: Room3D) -> void:
    if finalized || data == _current_data:
        return

func resolve_door_to_nothing(data: DoorData) -> void:
    if finalized || data == _current_data:
        return

func resolve_panic() -> void:
    if finalized:
        return

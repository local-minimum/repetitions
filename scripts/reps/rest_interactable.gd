extends InteractionBody3D
class_name RestInteractable

func _execute_interaction() -> void:
    if DungeonBuilder.active_builder == null:
        push_error("Cannot request rest if there's no dungeon builder active")
        return
    var coords: Vector3i = coordinates
    print_debug("Rest requested in %s at %s" % [_root, coords])
    __SignalBus.on_request_rest.emit(_root, coords)

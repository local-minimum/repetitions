extends InteractionBody3D
class_name RestInteractable

@export var _teddy: Teddy
@export var _teddy_event: Teddy.TeddySpecialEvent = Teddy.TeddySpecialEvent.NONE

func _execute_interaction() -> void:
    if DungeonBuilder.active_builder == null:
        push_error("Cannot request rest if there's no dungeon builder active")
        return
    var coords: Vector3i = coordinates
    if _teddy != null && _teddy_event != Teddy.TeddySpecialEvent.NONE:
        _teddy.run_event(_teddy_event)
    else:
        print_debug("Rest requested in %s at %s" % [_root, coords])
        __SignalBus.on_request_rest.emit(_root, coords)

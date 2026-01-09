extends SignalBusCore
class_name SignalBus

@warning_ignore_start("unused_signal")

signal on_hover_blueprint_room_enter(room: BlueprintRoom)
signal on_hover_blueprint_room_exit(room: BlueprintRoom)
signal on_blueprint_room_dropped(room: BlueprintRoom, drag_origin: Vector2i)

@warning_ignore_restore("unused_signal")

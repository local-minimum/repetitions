extends Node

@export var _tooltip: RoomTooltip
@export var _show_timer: Timer
@export var _hide_timer: Timer

func _enter_tree() -> void:
    if __SignalBus.on_hover_blueprint_room_enter.connect(_handle_blueprint_room_hover) != OK:
        push_error("Failed to connect hover blueprint room enter")
    if __SignalBus.on_hover_blueprint_room_exit.connect(_handle_blueprint_room_dehover) != OK:
        push_error("Failed to connect hover blueprint room exit")
    if __SignalBus.on_blueprint_room_move_start.connect(_handle_blueprint_drag_start) != OK:
        push_error("Failed to connect blueprint room move start")
    if __SignalBus.on_complete_dungeon_plan.connect(_handle_planning_done) != OK:
        push_error("Failed to connect complete dungeon plan")
    
func _exit_tree() -> void:
    __SignalBus.on_hover_blueprint_room_enter.disconnect(_handle_blueprint_room_hover)
    __SignalBus.on_hover_blueprint_room_exit.disconnect(_handle_blueprint_room_dehover)
    __SignalBus.on_blueprint_room_move_start.disconnect(_handle_blueprint_drag_start)
    __SignalBus.on_complete_dungeon_plan.disconnect(_handle_planning_done)

var _show_room: BlueprintRoom

func _handle_blueprint_room_hover(room: BlueprintRoom) -> void:
    if !_hide_timer.is_stopped():
        _hide_timer.stop()
        
    _show_room = room
    if _tooltip.visible:
        if !_hide_timer.is_stopped():
            _hide_timer.stop()
        _tooltip.show_tooltip(room.option)
    elif _show_timer.is_stopped():
        _show_timer.start()
        #print_debug("Started show")
        

func _handle_blueprint_room_dehover(room: BlueprintRoom) -> void:
    #print_debug("Exit room %s vs %s, showing %s" % [room, _show_room, _tooltip.visible])
    if _show_room != room || !_tooltip.visible:
        return
        
    _show_timer.stop()    
    _hide_timer.start()
    #print_debug("Started hide")
    

func _handle_blueprint_drag_start(_room: BlueprintRoom) -> void:
    _tooltip.hide()
    

func _handle_planning_done(_elevation: int, _rooms: Array[BlueprintRoom]) -> void:
    _tooltip.hide()


func _on_delay_show_timeout() -> void:
    if _show_room != null:
        _tooltip.show_tooltip(_show_room.option)


func _on_delay_hide_timeout() -> void:
    #print_debug("Do hide!")
    _tooltip.hide()

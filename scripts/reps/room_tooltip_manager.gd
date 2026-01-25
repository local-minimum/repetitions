extends Control

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
    if __SignalBus.on_blueprint_room_dropped.connect(_handle_blueprint_drag_stop) != OK:
        push_error("Failed to connect blueprint room dropped")
    if __SignalBus.on_complete_dungeon_plan.connect(_handle_planning_done) != OK:
        push_error("Failed to connect complete dungeon plan")
    
func _exit_tree() -> void:
    __SignalBus.on_hover_blueprint_room_enter.disconnect(_handle_blueprint_room_hover)
    __SignalBus.on_hover_blueprint_room_exit.disconnect(_handle_blueprint_room_dehover)
    __SignalBus.on_blueprint_room_move_start.disconnect(_handle_blueprint_drag_start)
    __SignalBus.on_blueprint_room_dropped.disconnect(_handle_blueprint_drag_stop)
    __SignalBus.on_complete_dungeon_plan.disconnect(_handle_planning_done)

var _show_room: BlueprintRoom
var _room_dragged: bool

        
func _handle_blueprint_room_hover(room: BlueprintRoom) -> void:
    if _room_dragged:
        return
        
    if !_hide_timer.is_stopped():
        _hide_timer.stop()
        
    _show_room = room
    if _tooltip.visible:
        if !_hide_timer.is_stopped():
            _hide_timer.stop()
        _tooltip.show_tooltip(room.option)
        _reposition_tooltip.call_deferred()
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
    _room_dragged = true
    queue_redraw()

func _handle_blueprint_drag_stop(_room: BlueprintRoom, _origin: Vector2, _orig_rot: float) -> void:
    _room_dragged = false    

func _handle_planning_done(_elevation: int, _rooms: Array[BlueprintRoom]) -> void:
    _tooltip.hide()
    queue_redraw()

func _on_delay_show_timeout() -> void:
    if _show_room != null:
        _tooltip.show_tooltip(_show_room.option)
        _reposition_tooltip.call_deferred()


func _on_delay_hide_timeout() -> void:
    #print_debug("Do hide!")
    _tooltip.hide()
    queue_redraw()

func _reposition_tooltip() -> void:
    if _show_room == null:
        return
    
    var tt_rect: Rect2 = _tooltip.get_global_rect()
    
    var vp_rect: Rect2 = _show_room.get_viewport_rect()
    
    var room_local_bb: Rect2 = _show_room.bounding_box()
    print_debug(room_local_bb)
    var room_position: Vector2 = _show_room.to_global(room_local_bb.position)
    var room_end: Vector2 = _show_room.to_global(room_local_bb.end)
    var room_min_x: float = minf(room_position.x, room_end.x)
    var room_min_y: float = minf(room_position.y, room_end.y)
    var room_max_x: float = maxf(room_position.x, room_end.x)
    var room_max_y: float = maxf(room_position.y, room_end.y)
    
    var fits_above: bool = room_min_y - tt_rect.size.y >= vp_rect.position.y
    var fits_flow_right: bool = room_min_x + tt_rect.size.x < vp_rect.end.x
    var fits_flow_left: bool = room_max_x - tt_rect.size.x >= vp_rect.position.x
    var fits_below: bool = room_max_y + tt_rect.size.y < vp_rect.end.y
    
    if fits_above && fits_flow_right:
        # Use position as anchor and flow to the right
        _tooltip.global_position = Vector2(room_min_x, room_min_y - tt_rect.size.y)
    
    elif fits_above && fits_flow_left:
        # Use upper right corner as anchor and float to the left
        _tooltip.global_position = Vector2(room_max_x - tt_rect.size.x, room_min_y - tt_rect.size.y)
    
    elif fits_below && fits_flow_right:
        _tooltip.global_position = Vector2(room_min_x, room_max_y)
    
    elif fits_below && fits_flow_left:
        _tooltip.global_position = Vector2(room_max_x - tt_rect.size.x, room_max_y)
    
    else:
        _tooltip.global_position = Vector2.ZERO
    
    queue_redraw()
       

func _draw() -> void:
    if _show_room == null:
        return
    
    
    

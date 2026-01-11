extends Node2D

@export var grid: Grid2D
@export var rooms: Array[BlueprintRoom]
@export var options: PlannerOptions
@export var debug: bool

func _ready() -> void:
    options.assign_grid(grid)
    
    for room: BlueprintRoom in rooms:
        room.grid = grid
        room.snap_to_grid()
        
func _enter_tree() -> void:
    if __SignalBus.on_blueprint_room_move_start.connect(_handle_room_move_start) != OK:
        push_error("Failed to connect room move start")
        
    if __SignalBus.on_blueprint_room_position_updated.connect(_handle_room_move) != OK:
        push_error("Failed to connect room position updated")
        
    if __SignalBus.on_blueprint_room_dropped.connect(_handle_room_dropped) != OK:
        push_error("Failed to connect room dropped")
        
func _exit_tree() -> void:
    __SignalBus.on_blueprint_room_move_start.disconnect(_handle_room_move_start)
    __SignalBus.on_blueprint_room_position_updated.disconnect(_handle_room_move)
    __SignalBus.on_blueprint_room_dropped.disconnect(_handle_room_dropped)

func _handle_room_move_start(room: BlueprintRoom) -> void:
    room.modulate = Color.GRAY
    options.remove_room(room)
    
func _handle_room_move(room: BlueprintRoom, _coords: Vector2i, valid: bool) -> void:
    # var t0: int = Time.get_ticks_usec() 
    # print_debug("<<< %s: Has moved!" % [room.summary()]) 
    if !valid:
        room.modulate = Color.WEB_GRAY
    
    elif _check_valid_room_placement(room, false):
        room.modulate = Color.SKY_BLUE
    
    if debug:
        queue_redraw()
    # var end: int = Time.get_ticks_usec()
    # print_debug("Room placement check %sus" % (end - t0))

        
func _handle_room_dropped(room: BlueprintRoom, _origin: Vector2, _origin_angle: float) -> void:
    if _check_valid_room_placement(room, true):
        room.placed = true
        room.modulate = Color.WHITE
        rooms.append(room)
    else:
        room.modulate = Color.WHITE
        options.add_room(room)

func _tween_return(room: BlueprintRoom, origin: Vector2, origin_angle: float) -> void:
        # print_debug("Invalid drop location for %s" % room)
        room.tweening = true
        var tween: Tween = create_tween()
        
        @warning_ignore_start("return_value_discarded")
        tween.tween_property(room, "global_position", origin, 0.2).set_trans(Tween.TRANS_SINE)
        if room.contained_in_grid:
            tween.tween_property(room, "rotation", origin_angle, 0.2)
        @warning_ignore_restore("return_value_discarded")
        
        if tween.finished.connect(
            func () -> void:
                room.tweening = false
                room.modulate = Color.WHITE
                if debug:
                    queue_redraw()
        ) != OK:
            push_warning("Failed to connect ease back complete")
            room.tweening = false
            room.modulate = Color.WHITE
            if debug:
                queue_redraw()
            
func _check_valid_room_placement(room: BlueprintRoom, finalize: bool) -> bool:
    if !room.contained_in_grid:
        room.modulate = Color.WEB_GRAY
        return false
     
    var touching_rooms: Array[BlueprintRoom] = []
       
    for other: BlueprintRoom in rooms:
        if other == room:
            continue
            
        match room.overlaps(other):
            BlueprintRoom.OVERLAP_NONE:
                continue
            BlueprintRoom.OVERLAP_ONTOP:
                if !finalize:
                    room.modulate = Color.RED
                return false
            BlueprintRoom.OVERLAP_TOUCH:
                # print_debug("%s touches %s" % [room, other])
                touching_rooms.append(other)
    
    if touching_rooms.is_empty():
        if !finalize:
            room.modulate = Color.GRAY
        return false
    
    var valid: bool = false
             
    for other: BlueprintRoom in touching_rooms:            
        var connected_doors: Array[DoorData]
        if room.has_connecting_doors(other, connected_doors):
            # print_debug("%s touches %s with doors %s" % [room, other, connected_doors])
            if connected_doors.any(func (door: DoorData) -> bool: return door.valid):
                valid = true
                if finalize:
                    room.register_connection(connected_doors)
                    other.register_connection(connected_doors)
                    
    if !valid && !finalize:
        room.modulate = Color.GRAY
                    
    return valid

func _draw() -> void:
    if !debug:
        return
    var show_area: bool = true
    var show_logical_tiles: bool = true
    
    for room: BlueprintRoom in rooms:
        var r: Rect2 = RectUtils.translate_local(room.bounding_box(), room, self).grow(9)
        draw_rect(r, Color.ORANGE, false, 2)
        
        if show_area:
            var points: PackedVector2Array = room.perimeter()
            for idx: int in range(points.size()):
                points[idx] = to_local(room.to_global(points[idx]))

            draw_polygon(points, [Color.ORANGE])
        
        if show_logical_tiles:
            var coords: Array[Vector2i] = room.get_global_used_tiles()
            for c: Vector2i in coords:
                var cell_rect: Rect2 = grid.get_local_cell_rect(c, true)
                cell_rect = RectUtils.translate_local(cell_rect, grid, self)
                draw_rect(cell_rect, Color.DEEP_PINK, false, 2)
                

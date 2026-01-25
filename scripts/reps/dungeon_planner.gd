extends Node2D
class_name DungeonPlanner

@export var _builder: DungeonBuilder
@export var grid: Grid2D


@export var _rooms_root: Node2D
@export var _icons_root: Node2D

var rooms: Array[BlueprintRoom]
@export var options: PlannerOptions
@export var pool: DraftPool
@export var draft_count: int = 4
@export var debug: bool

@export var seed_room: DraftOption
@export var seed_coordinates: Vector2i
@export var seed_direction: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.NORTH
@export var elevation: int = 0
@export var redraw_cost: int = 2

enum PlannerMode { PICK_ONE, PLACE_ALL }
@export var mode: PlannerMode = PlannerMode.PICK_ONE

@export var _terminal_scene: PackedScene
@export var _player_scene: PackedScene


var _player_icon: Control = null
var _terminals: Dictionary[PlannerTerminal, PlannerTerminalIcon]
var _active_terminal: PlannerTerminal
var _allowance: int = 0
var _sealed: bool

func _ready() -> void:
    if _seed_dungeon():
        complete_planning()
         
func _enter_tree() -> void:
    if __SignalBus.on_blueprint_room_move_start.connect(_handle_room_move_start) != OK:
        push_error("Failed to connect room move start")
        
    if __SignalBus.on_blueprint_room_position_updated.connect(_handle_room_move) != OK:
        push_error("Failed to connect room position updated")
        
    if __SignalBus.on_blueprint_room_dropped.connect(_handle_room_dropped) != OK:
        push_error("Failed to connect room dropped")
    
    if __SignalBus.on_complete_dungeon_plan.connect(_handle_complete_dungeon_plan) != OK:
        push_error("Failed to connect complete dungeon plan")
        
    if __SignalBus.on_ready_planner.connect(_handle_ready_planner) != OK:
        push_error("Failed to connect ready player")
        
func _exit_tree() -> void:
    __SignalBus.on_blueprint_room_move_start.disconnect(_handle_room_move_start)
    __SignalBus.on_blueprint_room_position_updated.disconnect(_handle_room_move)
    __SignalBus.on_blueprint_room_dropped.disconnect(_handle_room_dropped)
    __SignalBus.on_complete_dungeon_plan.disconnect(_handle_complete_dungeon_plan)
    __SignalBus.on_ready_planner.disconnect(_handle_ready_planner)

func _handle_ready_planner(terminal: PlannerTerminal, player: PhysicsGridPlayerController, d_elevation: int, allowance: int) -> void:
    if elevation != d_elevation:
        return
  
    if player == null:
        push_error("No player is known to %s so cannot show its position" % [self])
        _player_icon.hide()
    else:
        if _player_icon == null:
            _player_icon = _player_scene.instantiate()
            _icons_root.add_child(_player_icon)
            _player_icon.name = "Player"
        
        print_debug("Player is at %s (%s) which gives 2d %s" % [
            player.global_position,
            _builder.get_2d_grid_float_position(player.global_position),
            grid.get_global_pointf(_builder.get_2d_grid_float_position(player.global_position)),
        ])    
        _player_icon.global_position = grid.get_global_pointf(_builder.get_2d_grid_float_position(player.global_position))
        _player_icon.show()
        
    _active_terminal = terminal
    if !_terminals.has(terminal):
        var term_icon: PlannerTerminalIcon = _terminal_scene.instantiate()
        term_icon.name = "Terminal Marker: %s" % terminal.name
        _icons_root.add_child(term_icon)
        var grid_pos: Vector2 = _builder.get_2d_grid_float_position(terminal.global_position)
        term_icon.global_position = grid.get_global_pointf(grid_pos)
        _terminals[terminal] = term_icon

    _terminals[terminal].credits = allowance
         
    if player != null:
        player.cinematic = true
    
    _allowance = allowance
    get_canvas_layer_node().show()
    show()
    _draw_options()
    
    __SignalBus.on_update_planning.emit(self, _allowance)
    
func _handle_complete_dungeon_plan(d_elevation: int, d_rooms: Array[BlueprintRoom]) -> void:
    if elevation != d_elevation || rooms == d_rooms:
        return
    
    for room: BlueprintRoom in rooms:
        if !d_rooms.has(room):
            room.queue_free()
            
    rooms = d_rooms

var can_redraw_rooms: bool:
    get():
        return !_sealed && _allowance >= redraw_cost
         
func redraw_rooms()  -> void:
    if !can_redraw_rooms:
        push_warning("%s attempted redraw rooms on elevation %s but cost %s > %s or sealed %s" % [
            self, elevation, redraw_cost, _allowance, _sealed,
        ])
        return
    
    _allowance -= redraw_cost
    options.discard_rooms()
    _draw_options()
    __SignalBus.on_update_planning.emit(self, _allowance)
    _terminals[_active_terminal].credits = _allowance
    
func _draw_options() -> void:
    if _allowance <= 0 || _sealed:
        options.hide()
        options.hide_rooms()
        return
    elif !options.visible:
        options.show()
        options.show_rooms()
        
    for room_option: DraftOption in pool.draft(draft_count - options.size()):
        var room: BlueprintRoom = room_option.instantiate_blueprint_room()
        _rooms_root.add_child(room)
        options.add_room(room)
        
    options.assign_grid(grid)

func _seed_dungeon() -> bool:
    if seed_room == null:
        return false
    
    if rooms.any(func (br: BlueprintRoom) -> bool: return br.option == seed_room):
        return false
            
    var direction: CardinalDirections.CardinalDirection = (
        seed_direction if CardinalDirections.is_planar_cardinal(seed_direction) else CardinalDirections.ALL_PLANAR_DIRECTIONS.pick_random()
    )
    
    var blueprint: BlueprintRoom = seed_room.instantiate_blueprint_room()
    blueprint.grid = grid
    blueprint.global_position = grid.get_global_point(seed_coordinates)
    blueprint.global_rotation = CardinalDirections.direction_to_rotation_2d(direction)
    blueprint.placed = true
    blueprint.snap_to_grid()
    blueprint.option.drafted_count += 1
    
    rooms.append(blueprint)
    _rooms_root.add_child(blueprint)
    #print_debug("Seeding %s dungeon with %s at %s %s" % [seed_coordinates, blueprint, blueprint.global_position, grid.get_closest_coordinates(blueprint.global_position)])
    return true
    
func _handle_room_move_start(room: BlueprintRoom) -> void:
    room.z_index = 100
    room.modulate = Color.GRAY
    options.remove_room(room)
    
func _handle_room_move(room: BlueprintRoom, _coords: Vector2i, valid: bool) -> void:
    # var t0: int = Time.get_ticks_usec() e
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
        room.z_index = 3
        room.placed = true
        room.modulate = Color.WHITE
        rooms.append(room)
        room.option.drafted_count += 1
           
        if mode == PlannerMode.PICK_ONE:
            options.discard_rooms()

        _allowance -= 1
        __SignalBus.on_blueprint_room_placed.emit(room)
        __SignalBus.on_update_planning.emit(self, _allowance)
        _terminals[_active_terminal].credits = _allowance
        
        if !has_exposed_door():
            __SignalBus.on_elevation_plan_sealed.emit(elevation)
            _sealed = true
            options.hide_rooms()
            options.hide()  
        elif options.is_empty() && _allowance > 0:
            _draw_options()
        
        if _allowance <= 0:
            await get_tree().create_timer(0.7).timeout
            complete_planning()
            
    else:
        room.modulate = Color.WHITE
        options.add_room(room)

## If any of the placed rooms have a door that isn't connected or isn't leading into the walls
## of another room.
func has_exposed_door() -> bool:
    for room: BlueprintRoom in rooms:
        if room.has_unused_door():
            return true
    return false
        
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
                var cell_rect: Rect2 = grid.get_grid_cell_rect(c, true)
                cell_rect = RectUtils.translate_local(cell_rect, grid, self)
                draw_rect(cell_rect, Color.DEEP_PINK, false, 2)
                
func complete_planning() -> void:
    hide()
    get_canvas_layer_node().hide()
    __SignalBus.on_complete_dungeon_plan.emit(elevation, rooms)

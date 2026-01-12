extends Node2D
class_name PlannerOptions

@export var _rooms: Array[BlueprintRoom]
@export var _gap: float = 32
@export var _debug: bool
@export var _noease_dist_sq: float = 4

func is_empty() -> bool:
    return _rooms.is_empty()
    
func _ready() -> void:
    _sync_placements()
    
func _sync_placements() -> void:
    var shapes: Dictionary[BlueprintRoom, Rect2]
    var origins: Dictionary[BlueprintRoom, Vector2]
    var total_height: float = _gap * (_rooms.size() - 1)
    
    for room: BlueprintRoom in _rooms:
        var r: Rect2 = RectUtils.translate_local(room.bounding_box(), room, self)    
        total_height += r.size.y
        shapes[room] = r
        origins[room] = to_local(room.global_position)
        
    var available_height: float = to_local(get_viewport_rect().size).y

    var y_anchor: float =  (available_height - total_height) / 2.0
    var y_used: float = 0.0
    
    # print_debug("Using %s out of %s height" % [total_height, available_height])
    for room: BlueprintRoom in _rooms:
        var d: Vector2 = shapes[room].get_center() - origins[room]
        var pt: Vector2 = Vector2(0.0, y_anchor + y_used + shapes[room].size.y / 2) - d
        var target: Vector2 = to_global(pt)
        if target.distance_squared_to(room.global_position) < _noease_dist_sq:
            room.global_position = target
        else:
            room.tweening = true
            var tween: Tween = create_tween()
            @warning_ignore_start("return_value_discarded")
            tween.tween_property(room, "global_position", target, 0.5)
            @warning_ignore_restore("return_value_discarded")
            if tween.finished.connect(
                func () -> void:
                    room.tweening = false
            ) != OK:
                push_error("Failed to connect tween finished")
                room.tweening = false
                
        y_used += shapes[room].size.y + _gap
    
    if _debug:    
        queue_redraw()

var _last_removed: BlueprintRoom
var _last_removed_idx: int
    
func remove_room(room: BlueprintRoom) -> void:
    _last_removed = room
    _last_removed_idx = _rooms.find(room)
    
    _rooms.erase(room)
    _sync_placements()

func add_room(room: BlueprintRoom) -> void:
    var added: bool = false
    if room == _last_removed:
        if _rooms.insert(_last_removed_idx, room) == OK:
            added = true
    
    if !added:
        _rooms.append(room)
    _sync_placements()

func assign_grid(grid: Grid2D) -> void:
    for room: BlueprintRoom in _rooms:
        room.grid = grid
        
func _draw() -> void:
    if !_debug:
        return
        
    for room: BlueprintRoom in _rooms:
        var r: Rect2 = RectUtils.translate_local(room.bounding_box(), room, self)
        draw_rect(r, Color.CORAL)

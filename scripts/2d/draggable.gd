extends Resource
class_name Draggable

@export var no_drag_zone_sq: float = 4
 
@export var snap_to_grid: bool = true
@export_range(0.0, 0.5) var snap_distance_fraction: float = 0.5

@export var allow_rotation: bool = true
@export var rotate_clockwise_action: String
@export var rotate_counter_clockwise_action: String

func dragging(node: Node2D) -> bool:
    return node == _dragging && _dragging != null

var rotating: bool:
    get():
        return _rotating

var _disabled: Array[Node2D]
            
var grid: Grid2D
var _rotating: bool
var _hovered: Node2D
var _dragging: Node2D

var _drag_start: Vector2
var _drag_origin: Vector2i
var _drag_origin_valid: bool

signal on_grid_drag_end(node: Node2D, start_point: Vector2, from: Vector2i, from_valid: bool, to: Vector2i, to_valid: bool)
    
const DIR_NORTH: int = 0
const DIR_WEST: int = 1
const DIR_SOUTH: int = 2
const DIR_EAST: int = 3

func enable(node: Node2D) -> void:
    _disabled.erase(node)

func disable(node: Node2D) -> void:
    if _dragging == node:
        InputCursorHelper.remove_state(node, InputCursorHelper.State.DRAG)
        _dragging = null
        _emit_drag_end(node)
        
    if !_disabled.has(node):
        _disabled.append(node)
    
func calculate_coordinates(node: Node2D) -> Vector2i:
    if grid != null:
        return grid.get_closest_coordinates(node.global_position)
        
    return Vector2i.ONE * -1

func translate_coords_array_to_global(node: Node2D, coords: Array[Vector2i]) -> Array[Vector2i]:
    var origin: Vector2i = calculate_coordinates(node)
    var res: Array[Vector2i]

    match _get_rotation_direction(node):
        DIR_NORTH:
            res.append_array(coords)
        DIR_WEST:
            res.append_array(coords.map(func (c: Vector2i) -> Vector2i: return Vector2i(-c.y, c.x)))
        DIR_SOUTH:
            res.append_array(coords.map(func (c: Vector2i) -> Vector2i: return Vector2i(-c.x, -c.x)))   
        DIR_EAST:
            res.append_array(coords.map(func (c: Vector2i) -> Vector2i: return Vector2i(c.y, -c.x)))
             
    return Array(res.map(func (c: Vector2i) -> Vector2i: return c + origin), TYPE_VECTOR2I, "", null)

func translate_coord_to_local(node: Node2D, coords: Vector2i) -> Vector2i:
    var origin: Vector2i = calculate_coordinates(node)
    coords -= origin
    
    match _get_rotation_direction(node):
        DIR_NORTH:
            return coords
        DIR_SOUTH:
            return Vector2i(-coords.x, -coords.y)
        DIR_WEST:
            return Vector2i(coords.y, -coords.x)
        DIR_EAST:
            return Vector2i(-coords.y, coords.x)
        _:
            return coords
                
func handle_input_event(node: Node2D, event: InputEvent) -> void:
    if _disabled.has(node):
        return
    
    if allow_rotation:
        if !rotate_counter_clockwise_action.is_empty() && event.is_action_pressed(rotate_counter_clockwise_action):
            _rotate_right_angle(node, 1)
            
        elif !rotate_clockwise_action.is_empty() && event.is_action_pressed(rotate_clockwise_action):
            _rotate_right_angle(node, -1)
    
    if event.is_echo():
        return
        
    if event is InputEventMouseButton:
        var mbtn: InputEventMouseButton = event
        if mbtn.button_index == MOUSE_BUTTON_LEFT:
            # print_debug("[Draggable %s] Left mouse %s clicked me while %s hovered" % [node.name, mbtn, _hovered])
            if mbtn.pressed:
                _handle_drag_start(node)
            else:
                _handle_drag_end(node)
    elif _dragging && event is InputEventMouseMotion:
        # print_debug("[Blueprint Room %s] Handled drag event %s" % [name, event])
        _handle_drag(node, event as InputEventMouseMotion)
        
func _get_rotation_direction(node: Node2D) -> int:
    var dir: float = node.global_transform.get_rotation() / (0.5 * PI)
    var diri: int = roundi(dir)
    if abs(dir - diri) > 0.01:
        push_error("[Draggable %s] Has global rotation %s, expected to follow a cardinal" % [node.name, node.global_transform.get_rotation()])

    return posmod(diri, 4)

func get_global_direction(node: Node2D, local_direction: CardinalDirections.CardinalDirection) -> CardinalDirections.CardinalDirection:
    match _get_rotation_direction(node):
        DIR_NORTH:
            return local_direction
        DIR_SOUTH:
            return CardinalDirections.invert(local_direction)
        DIR_WEST:
            return CardinalDirections.yaw_ccw(local_direction)[0]
        DIR_EAST:
            return CardinalDirections.yaw_cw(local_direction)[0]
        _:
            return local_direction     
 
func get_local_direction(node: Node2D, global_direction: CardinalDirections.CardinalDirection) -> CardinalDirections.CardinalDirection:
     match _get_rotation_direction(node):
        DIR_NORTH:
            return global_direction
        DIR_SOUTH:
            return CardinalDirections.invert(global_direction)
        DIR_WEST:
            return CardinalDirections.yaw_cw(global_direction)[0]
        DIR_EAST:
            return CardinalDirections.yaw_ccw(global_direction)[0]
        _:
            return global_direction     
       
func _rotate_right_angle(node: Node2D, step: int) -> void:
    if _rotating:
        return
    _rotating = true
    var target_rotation_direction: int = posmod(_get_rotation_direction(node) + step, 4)
    var target_angle: float = 0
    match target_rotation_direction:
        DIR_NORTH:
            pass
        DIR_WEST:
            target_angle = PI * 0.5
        DIR_SOUTH:
            target_angle = PI
        DIR_EAST:
            target_angle = PI * 1.5
    
    if (target_angle - node.global_rotation) > PI:
        target_angle -= 2 * PI
    elif target_angle - node.global_rotation < -PI:
        target_angle += 2 * PI
        
    var tween: Tween = node.create_tween()
    
    @warning_ignore_start("return_value_discarded")
    tween.tween_property(node, "global_rotation", target_angle, 0.5).set_trans(Tween.TRANS_SINE)
    @warning_ignore_restore("return_value_discarded")
    
    if tween.finished.connect(
        func () -> void:
            _rotating = false
    ) != OK:
        push_warning("Could not listen to end of rotation tween")
        _rotating = false

func unhandled_input(node: Node2D, event: InputEvent) -> void:
    if _dragging == null || _dragging != node:
        return
    
    if event is InputEventMouseButton:
        var mbtn: InputEventMouseButton = event
        if mbtn.button_index == MOUSE_BUTTON_LEFT && !mbtn.pressed && !mbtn.is_echo():
            _handle_drag_end(node)
            node.get_viewport().set_input_as_handled()
            
    elif event is InputEventMouseMotion:
        _handle_drag(node, event as InputEventMouseMotion)
        
func _handle_drag(node: Node2D, event: InputEventMouseMotion) -> void:
    if node == null || node != _dragging:
        return
        
    node.global_position += event.relative
    node.get_viewport().set_input_as_handled()
       
func _handle_drag_start(node: Node2D) -> void:
    # print_debug("[Draggable %s] Start draggin while %s hovered" % [node.name, _hovered])
    
    if _dragging == node || _hovered != node:
        return
        
    elif _dragging != null:
        _handle_drag_end(_dragging)
       
    _dragging = node
    
    _drag_start = node.global_position
    _drag_origin = calculate_coordinates(node)
    _drag_origin_valid = grid != null && grid.is_inside_grid(node.global_position)
    
    InputCursorHelper.remove_node(node)
    InputCursorHelper.add_state(node, InputCursorHelper.State.DRAG)              
    
func _handle_drag_end(node: Node2D) -> void:
    # print_debug("[Draggable %s] End dragging while %s is dragged" % [node.name, _dragging])
    
    if _dragging != node || node == null:
        return
  
    _dragging = null
    InputCursorHelper.remove_node(node)
    if _hovered == node:
        InputCursorHelper.add_state(node, InputCursorHelper.State.HOVER)
    
        
    if node.global_position.distance_squared_to(_drag_start) < no_drag_zone_sq:
        node.global_position = _drag_start
        return  
        
    _emit_drag_end(node)
    
func _emit_drag_end(node: Node2D) -> void:    
    on_grid_drag_end.emit(
        node,
        _drag_start,
        _drag_origin,
        _drag_origin_valid,
        calculate_coordinates(node),
        grid != null && grid.is_inside_grid(node.global_position)
    )
    
func handle_mouse_enter(node: Node2D) -> void:
    # print_debug("[Draggable %s] Mouse enter" % [node.name])
    if _disabled.has(node) || _hovered == node:
        return
    elif _hovered != null:
        handle_mouse_exit(_hovered)
    
    _hovered = node
    if !_disabled.has(node):
        InputCursorHelper.add_state(node, InputCursorHelper.State.HOVER)
    
func handle_mouse_exit(node: Node2D) -> void:
    if _hovered != node || node == null:
        return
        
    _hovered = null
    InputCursorHelper.remove_state(node, InputCursorHelper.State.HOVER)

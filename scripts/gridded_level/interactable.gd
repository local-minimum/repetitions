extends Node3D
class_name Interactable

@export var _debug: bool
@export var _collission_shape: CollisionShape3D

var physics_body: PhysicsBody3D:
    get():
        if _collission_shape == null:
            return null
        return _collission_shape.get_parent() as PhysicsBody3D
        
var is_interactable: bool = true:
    set(value):
        is_interactable = value
        if value:
            __SignalBus.on_allow_interactions.emit(self)
        else:
            __SignalBus.on_disallow_interactions.emit(self)
            
var _level: GridLevelCore
var player: GridPlayerCore:
    get():
        return _level.player if _level != null else null
        
var _hovered: bool
var _showing_cursor_hand: bool
    
func _enter_tree() -> void:
    if __SignalBus.on_level_loaded.connect(_handle_level_loaded) != OK:
        push_error("Failed to connect to level loaded")
    if __SignalBus.on_level_unloaded.connect(_handle_level_unloaded) != OK:
        push_error("Failed to connect to level unloaded")
        
    var body: PhysicsBody3D = physics_body
    if body == null:
        return
    if (
        !body.mouse_entered.is_connected(_on_static_body_3d_mouse_entered) &&
        body.mouse_entered.connect(_on_static_body_3d_mouse_entered) != OK
    ):
        push_warning("Failed to connect mouse entered body")
    
    if (
        !body.mouse_exited.is_connected(_on_static_body_3d_mouse_exited) &&
        body.mouse_exited.connect(_on_static_body_3d_mouse_exited) != OK
    ):
        push_warning("Failed to connect mouse exited body")       

    if (
        !body.input_event.is_connected(_on_static_body_3d_input_event) &&
        body.input_event.connect(_on_static_body_3d_input_event) != OK
    ):
        push_warning("Failed to connect body input event")
        
func _exit_tree() -> void:
    is_interactable = false
    
    __SignalBus.on_level_loaded.disconnect(_handle_level_loaded)
    __SignalBus.on_level_unloaded.disconnect(_handle_level_unloaded)    
    
    var body: PhysicsBody3D = physics_body  
    if body != null:
        body.mouse_entered.disconnect(_on_static_body_3d_mouse_entered)
        body.mouse_exited.disconnect(_on_static_body_3d_mouse_exited)
        body.input_event.disconnect(_on_static_body_3d_input_event)

    
func _handle_level_unloaded(level: GridLevelCore) -> void:
    if _level == level:
        _level = null

func _handle_level_loaded(level: GridLevelCore) -> void:
    _level = level
            
func player_is_in_range() -> bool:
    return _in_range(player.center.global_position)

func bounding_box() -> AABB:
    var size: Vector3 = Vector3.ONE
    var center: Vector3 = _collission_shape.global_position
    
    var body: PhysicsBody3D = NodeUtils.body3d(self)
    if body != null:
        center = body.global_position
            
    if _collission_shape.shape is BoxShape3D:
        var box: BoxShape3D = _collission_shape.shape
        size = _collission_shape.global_basis * box.size

    elif _collission_shape.shape is SphereShape3D:
        var sphere: SphereShape3D = _collission_shape.shape
        size = _collission_shape.global_basis * (sphere.radius * Vector3i.ONE)
        
    elif _collission_shape.shape is ConvexPolygonShape3D:
        var poly_shape: ConvexPolygonShape3D = _collission_shape.shape
        var trans: Callable = _collission_shape.to_global
        
        if body != null:
            # TODO: This is a hack, kinda or but the points of a collision shape seems to be in the body's coordinate system!
            # And converting to global using the collision shapes transform doesn't work
            trans = body.to_global
            # trans = func (v: Vector3) -> Vector3:
            #     return v * _collission_shape.global_transform.affine_inverse()    
                    
        return AABBUtils.create_bounding_box(poly_shape.points, trans)
        
    else:
        push_warning("Collision shape %s type not handled" % _collission_shape.shape)

    return AABB(center - size * 0.5, size)

var global_center: Vector3:
    get():
        var body: PhysicsBody3D = NodeUtils.body3d(self)
        if body != null:
            return body.global_position
            
        if _collission_shape.shape is BoxShape3D:
            return _collission_shape.global_position

        elif _collission_shape.shape is SphereShape3D:
            return _collission_shape.global_position
        elif _collission_shape.shape is ConvexPolygonShape3D:
            var poly_shape: ConvexPolygonShape3D = _collission_shape.shape
            if poly_shape.points.is_empty():
                return global_position
                
            var center: Vector3 = Vector3.ZERO
            for pt: Vector3 in poly_shape.points:
                center += pt
            center /= poly_shape.points.size()
            return _collission_shape.to_global(center)
                       
        push_warning("Collision shape %s type not handled" % _collission_shape.shape)
        return _collission_shape.global_position
        
## Determines if entity should be allowed to interact based on geometry
func _in_range(_entity_position: Vector3) -> bool:
    return true

## Determines if when interacting, it should be allowed or refused
func check_allow_interact() -> bool:
    return true

func execute_interation() -> void:
    pass

func _on_static_body_3d_input_event(
    _camera: Node,
    event: InputEvent,
    _event_position: Vector3,
    _normal: Vector3,
    _shape_idx: int,
) -> void:
    if !is_interactable:
        return

    if _in_range(player.center.global_position):
        if !_showing_cursor_hand:
            if _debug:
                print_debug("[Interactable %s] Showing cursor hand" % self)
            InputCursorHelper.add_state(self, InputCursorHelper.State.HOVER)
            _showing_cursor_hand = true
    else:
        if _showing_cursor_hand:
            if _debug:
                print_debug("[Interactable %s] Return to cursor arrow" % self)
            InputCursorHelper.remove_state(self, InputCursorHelper.State.HOVER)
            _showing_cursor_hand = false

        return

    if event is InputEventMouseButton && !event.is_echo():
        var mouse_event: InputEventMouseButton = event

        if mouse_event.pressed && mouse_event.button_index == MOUSE_BUTTON_LEFT:
            if check_allow_interact():
                execute_interation()

func _on_static_body_3d_mouse_entered() -> void:
    _hovered = true
    InputCursorHelper.add_state(self, InputCursorHelper.State.HOVER)
    if is_interactable && _in_range(player.center.global_position):
        if _debug:
            print_debug("[Interactable %s] Showing cursor hand (entered)" % self)
        _showing_cursor_hand = true

func _on_static_body_3d_mouse_exited() -> void:
    _hovered = false
    _showing_cursor_hand = false
    InputCursorHelper.remove_state(self, InputCursorHelper.State.HOVER)
    if _debug:
        print_debug("[Interactable %s] Showing cursor arrow (exit)" % self)

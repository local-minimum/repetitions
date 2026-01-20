extends CharacterBody3D
class_name PhysicsGridPlayerController

var builder: DungeonBuilder
var cinematic: bool:
    set(value):
        _translation_stack.clear()
        _translation_pressed.clear()
        cinematic = value

@export var _camera: Camera3D
var camera: Camera3D:
    get():
        return _camera

@export var _forward: ShapeCast3D
@export var _left: ShapeCast3D
@export var _right: ShapeCast3D
@export var _backward: ShapeCast3D 

@export_range(0, 1) var _translation_duration: float = 0.3
@export_range(0, 1) var _rotation_duration: float = 0.25
@export_range(0, 1) var _refuse_distance_forward: float = 0.2
@export_range(0, 1) var _refuse_distance_other: float = 0.1

@export var _gridless_translation_speed: float = 5.0
@export var _gridless_rotation_speed: float = 0.8
@export var _gridless_friction: float = 0.5
@export var _mouse_sensitivity_yaw: float = 1.0
@export var _mouse_sensistivity_pitch: float = 1.0
@export var _gridless_camera_near: float = 0.05
@export var _gridless_camera_fov: float = 70   

@export var _camera_transition_time: float = 0.2

var _gridded_cam_offset: Vector3
var _gridless_cam_offset: Vector3
var _gridded_cam_near: float
var _gridded_cam_fov: float

var _cam_slide_tween: Tween
var _translation_tween: Tween
var _rotation_tween: Tween

var _translation_stack: Array[Movement.MovementType]
var _translation_pressed: Dictionary[Movement.MovementType, bool]

## This should be false if instant movement or settings say no
var _allow_continious_translation: bool = true

var gridless: bool:
    set(value): 
        if gridless != value:
            _translation_stack.clear()
            _translation_pressed.clear()
            velocity = Vector3.ZERO          
        
            if value:
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
                if _cam_slide_tween && _cam_slide_tween.is_running():
                    _cam_slide_tween.kill()
                _cam_slide_tween = create_tween()
                @warning_ignore_start("return_value_discarded")
                _cam_slide_tween.tween_property(_camera, "position", _gridless_cam_offset, _camera_transition_time)
                _cam_slide_tween.tween_property(_camera, "near", _gridless_camera_near, _camera_transition_time)
                _cam_slide_tween.tween_property(_camera, "fov", _gridless_camera_fov, _camera_transition_time)
                @warning_ignore_restore("return_value_discarded")
            else:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  
                if _cam_slide_tween && _cam_slide_tween.is_running():
                    _cam_slide_tween.kill()
                _cam_slide_tween = create_tween()
                @warning_ignore_start("return_value_discarded")
                _cam_slide_tween.tween_property(_camera, "position", _gridded_cam_offset, _camera_transition_time)
                _cam_slide_tween.tween_property(_camera, "near", _gridded_cam_near, _camera_transition_time)
                _cam_slide_tween.tween_property(_camera, "fov", _gridded_cam_fov, _camera_transition_time)
                @warning_ignore_restore("return_value_discarded")
                # Force alignment with grid
                _attempt_translation(Movement.MovementType.CENTER, null, Vector3.ZERO)
                _attempt_turn(0.0)
                                
        gridless = value

func _ready() -> void:
    _gridded_cam_offset = _camera.position
    
    _gridless_cam_offset = _camera.position
    _gridless_cam_offset.x = 0
    _gridless_cam_offset.z = 0
    
    _gridded_cam_fov = _camera.fov
    _gridded_cam_near = _camera.near
    
    __SignalBus.on_physics_player_ready.emit(self)
              
func _input(event: InputEvent) -> void:
    var handled: bool = true
    if event.is_echo():
        return
        
    if event.is_action_pressed("crawl_forward"):
        _push_ontop_of_movement_stack(Movement.MovementType.FORWARD)
        
    elif event.is_action_released("crawl_forward"):
        _release_movement(Movement.MovementType.FORWARD)
        
    elif event.is_action_pressed("crawl_strafe_left"):
        _push_ontop_of_movement_stack(Movement.MovementType.STRAFE_LEFT)

    elif event.is_action_released("crawl_strafe_left"):
        _release_movement(Movement.MovementType.STRAFE_LEFT)
        
    elif event.is_action_pressed("crawl_strafe_right"):
        _push_ontop_of_movement_stack(Movement.MovementType.STRAFE_RIGHT)

    elif event.is_action_released("crawl_strafe_right"):
        _release_movement(Movement.MovementType.STRAFE_RIGHT)
        
    elif event.is_action_pressed("crawl_backward"):
        _push_ontop_of_movement_stack(Movement.MovementType.BACK)
    
    elif event.is_action_released("crawl_backward"):
        _release_movement(Movement.MovementType.BACK)

    else:
        handled = false
        
    if handled && !cinematic:
        get_viewport().set_input_as_handled()
    
    if gridless && event is InputEventMouseMotion:
        var mouse: InputEventMouseMotion = event
        rotation.y -= mouse.relative.x * _mouse_sensitivity_yaw
        var new_pitch: float = _camera.rotation.x - mouse.relative.y * _mouse_sensistivity_pitch
        _camera.rotation.x = clampf(new_pitch, -PI * 2/3, PI * 2/3)
 
func _push_ontop_of_movement_stack(movement: Movement.MovementType) -> void:
    if cinematic:
        return
        
    if gridless:
        if !_translation_stack.has(movement):
            _translation_stack.append(movement)
    else:
        _translation_stack.append(movement)
        _translation_pressed[movement] = _allow_continious_translation

func _release_movement(movement: Movement.MovementType) -> void:
    if gridless:
        _translation_stack.erase(movement)
    else:
        _translation_pressed[movement] = false
                
func _physics_process(delta: float) -> void:
    if cinematic:
        return
        
    if gridless:
        _gridless_movement(delta)
    else:
        _gridfull_movement()

func _gridless_movement(delta: float) -> void:
    if !_translation_stack.is_empty():
        var direction: Vector3 = Vector3.ZERO
        for movement: Movement.MovementType in _translation_stack:
            match movement:
                Movement.MovementType.FORWARD:
                    direction += -basis.z
                Movement.MovementType.STRAFE_LEFT:
                    direction += -basis.x
                Movement.MovementType.STRAFE_RIGHT:
                    direction += basis.x
                Movement.MovementType.BACK:
                    direction += basis.z
                _:
                    push_error("Player %s's movement %s is not a valid translation" % [name, Movement.name(movement)])       
        if direction.length_squared() > 1.0:
            direction = direction.normalized()
        
        if direction.length_squared() > 0.0: 
            var v: Vector3 = direction * _gridless_translation_speed
            velocity.x = v.x
            velocity.z = v.z
    
    else:
        var v: Vector3 = velocity.lerp(Vector3.ZERO, _gridless_friction * delta)
        velocity.x = v.x
        velocity.z = v.z
            
    var angle: float = 0.0
    if Input.is_action_pressed("crawl_turn_left"):
        angle = TAU * delta * _gridless_rotation_speed
    elif Input.is_action_pressed("crawl_turn_right"):
        angle = -TAU * delta * _gridless_rotation_speed
    
    if angle != 0.0:
        basis = transform.rotated(Vector3.UP, angle).basis          
    
    if move_and_slide():
        # Collides with something
        pass
            
func _gridfull_movement() -> void:
    if !_translation_stack.is_empty():
        var movement: Movement.MovementType = _translation_stack[0]
        match movement:
            Movement.MovementType.FORWARD:
                _attempt_translation(movement, _forward, Vector3.FORWARD)
            Movement.MovementType.STRAFE_LEFT:
                _attempt_translation(movement, _left, Vector3.LEFT)
            Movement.MovementType.STRAFE_RIGHT:
                _attempt_translation(movement, _right, Vector3.RIGHT)
            Movement.MovementType.BACK:
                _attempt_translation(movement, _backward, Vector3.BACK)
            _:
                push_error("Player %s's movement %s is not a valid translation" % [name, Movement.name(movement)])
        
    if Input.is_action_just_pressed("crawl_turn_left"):
        _attempt_turn(PI * 0.5)
    elif Input.is_action_just_pressed("crawl_turn_right"):
        _attempt_turn(-PI * 0.5)
        
func _attempt_translation(movement: Movement.MovementType, caster: ShapeCast3D, direction: Vector3) -> void:
    if _translation_tween && _translation_tween.is_running() || _rotation_tween && _rotation_tween.is_running():
        return
        
    if caster != null && caster.is_colliding():
        _refuse_movement(movement, caster, direction)
        return
        
    var target: Vector3 = builder.get_floor_center(global_position, (to_global(direction) - global_position).normalized())
    
    _translation_tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    _translation_tween.tween_property(self, "global_position", target, _translation_duration)
    @warning_ignore_restore("return_value_discarded")
    if _translation_tween.finished.connect(_handle_translation_end.bind(movement)) != OK:
        push_warning("Failed to connect end of movement")
        _handle_translation_end(movement)

func _handle_translation_end(movement: Movement.MovementType) -> void:
    if !_translation_pressed.get(movement, false):
        _translation_stack.erase(movement)
        
func _refuse_movement(movement: Movement.MovementType, caster: ShapeCast3D, direction: Vector3) -> void:
    print_debug("Refusing movement %s because %s hits %s of %s" % [
        Movement.name(movement),
        caster,
        caster.get_collider(0) if caster else null,
        (caster.get_collider(0) as Node3D).get_parent_node_3d(),
    ])
    var target: Vector3 = builder.get_floor_center(global_position, (to_global(direction) - global_position).normalized())
    var pt: Vector3 = caster.get_collision_point(0)
    
    var l: float = global_position.distance_to(pt)
    l = minf(l, global_position.distance_to(target))
    if movement == Movement.MovementType.FORWARD:
        l *= _refuse_distance_forward
    else:
        l *= _refuse_distance_other
    
    var mid: Vector3 = global_position + l * (target - global_position)
    
    _translation_tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    _translation_tween.tween_property(self, "global_position", mid, _translation_duration * 0.5)
    _translation_tween.tween_property(self, "global_position", global_position, _translation_duration * 0.5)
    @warning_ignore_restore("return_value_discarded")
    
    if _translation_tween.finished.connect(_handle_translation_end.bind(movement)) != OK:
        push_error("Failed to connect to translation tween end")
        _handle_translation_end(movement)
    
func _attempt_turn(angle: float) -> void:
    if  _rotation_tween && _rotation_tween.is_running():
        return
    
    var t: Transform3D = global_transform.rotated(Vector3.UP, angle)
    var target_global_rotation: Quaternion = builder.get_cardial_rotation(t.basis.get_rotation_quaternion())
    
    _rotation_tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    var tween_func: Callable = QuaternionUtils.create_tween_rotation_method(self)
    _rotation_tween.tween_method(tween_func, global_transform.basis.get_rotation_quaternion(), target_global_rotation, _rotation_duration)
    @warning_ignore_restore("return_value_discarded")

static func find_player_in_tree(body: Node3D) -> PhysicsGridPlayerController:
    while body != null:
        if body is PhysicsGridPlayerController:
            return body as PhysicsGridPlayerController
    
        body = body.get_parent_node_3d()
        
    return null

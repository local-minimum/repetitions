extends Node3D
class_name PhysicsGridPlayerController

var builder: DungeonBuilder

@export var _forward: ShapeCast3D
@export var _left: ShapeCast3D
@export var _right: ShapeCast3D
@export var _backward: ShapeCast3D 
@export_range(0, 1) var _translation_duration: float = 0.3
@export_range(0, 1) var _rotation_duration: float = 0.25
@export_range(0, 1) var _refuse_distance_forward: float = 0.2
@export_range(0, 1) var _refuse_distance_other: float = 0.1
var _translation_tween: Tween
var _rotation_tween: Tween

var _translation_stack: Array[Movement.MovementType]
var _translation_pressed: Dictionary[Movement.MovementType, bool]

## This should be false if instant movement or settings say no
var _allow_continious_translation: bool = true

func _input(event: InputEvent) -> void:
    var handled: bool = true
    if event.is_echo():
        return
        
    if event.is_action_pressed("crawl_forward"):
        _push_ontop_of_movement_stack(Movement.MovementType.FORWARD)
        
    elif event.is_action_released("crawl_forward"):
        _translation_pressed[Movement.MovementType.FORWARD] = false
        
    elif event.is_action_pressed("crawl_strafe_left"):
        _push_ontop_of_movement_stack(Movement.MovementType.STRAFE_LEFT)

    elif event.is_action_released("crawl_strafe_left"):
        _translation_pressed[Movement.MovementType.STRAFE_LEFT] = false
        
    elif event.is_action_pressed("crawl_strafe_right"):
        _push_ontop_of_movement_stack(Movement.MovementType.STRAFE_RIGHT)

    elif event.is_action_released("crawl_strafe_right"):
        _translation_pressed[Movement.MovementType.STRAFE_RIGHT] = false
        
    elif event.is_action_pressed("crawl_backward"):
        _push_ontop_of_movement_stack(Movement.MovementType.BACK)
    
    elif event.is_action_released("crawl_backward"):
        _translation_pressed[Movement.MovementType.BACK] = false

    else:
        handled = false
        
    if handled:
        get_viewport().set_input_as_handled()
 
func _push_ontop_of_movement_stack(movement: Movement.MovementType) -> void:
    _translation_stack.append(movement)
    _translation_pressed[movement] = _allow_continious_translation

func _release_movement(movement: Movement.MovementType) -> void:
    var idx: int = _translation_stack.find(movement)
    if idx < 0:
        return
    _translation_pressed[movement] = false
                
func _physics_process(_delta: float) -> void:
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
        _attempt_turn(PI / 2)
    elif Input.is_action_just_pressed("crawl_turn_right"):
        _attempt_turn(-PI / 2)
        
func _attempt_translation(movement: Movement.MovementType, caster: ShapeCast3D, direction: Vector3) -> void:
    if _translation_tween && _translation_tween.is_running() || _rotation_tween && _rotation_tween.is_running():
        return
        
    if caster.is_colliding():
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

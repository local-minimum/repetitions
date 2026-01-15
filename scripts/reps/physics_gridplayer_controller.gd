extends Node3D
class_name PhysicsGridPlayerController

var builder: DungeonBuilder

@export var _forward: ShapeCast3D
@export var _left: ShapeCast3D
@export var _right: ShapeCast3D
@export var _backward: ShapeCast3D 
@export_range(0, 1) var _translation_duration: float = 0.3
@export_range(0, 1) var _rotation_duration: float = 0.25

var _translation_tween: Tween
var _rotation_tween: Tween

func _physics_process(_delta: float) -> void:
    if Input.is_action_pressed("crawl_forward"):
        _attempt_translation(_forward, Vector3.FORWARD)
    elif Input.is_action_pressed("crawl_strafe_left"):
        _attempt_translation(_left, Vector3.LEFT)
    elif Input.is_action_pressed("crawl_strafe_right"):
        _attempt_translation(_right, Vector3.RIGHT)
    elif Input.is_action_pressed("crawl_backward"):
        _attempt_translation(_backward, Vector3.BACK)
        
    if Input.is_action_just_pressed("crawl_turn_left"):
        _attempt_turn(PI / 2)
    elif Input.is_action_just_pressed("crawl_turn_right"):
        _attempt_turn(-PI / 2)
        
func _attempt_translation(caster: ShapeCast3D, direction: Vector3) -> void:
    if caster.is_colliding():
        # print_debug("%s collides with something" % [caster])
        return
    
    if _translation_tween && _translation_tween.is_running() || _rotation_tween && _rotation_tween.is_running():
        return
        
    var target: Vector3 = builder.get_floor_center(global_position, (to_global(direction) - global_position).normalized())
    
    _translation_tween = create_tween()
    @warning_ignore_start("return_value_discarded")
    _translation_tween.tween_property(self, "global_position", target, _translation_duration)
    @warning_ignore_restore("return_value_discarded")

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

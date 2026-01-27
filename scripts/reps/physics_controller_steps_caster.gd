@tool
extends ShapeCast3D
class_name PhysicsControllerStepCaster

@export var step_direction: Vector2:
    set(value):
        step_direction = value
        _sync_cast_origin()
        
@export var step_distance: float = 0.2:
    set(value):
        step_distance = value
        _sync_cast_origin()
    
@export var step_height_max: float = 0.35:
    set(value):
        step_height_max = value
        _sync_cast_origin()

@export var step_down_max: float = 0.35:
    set(value):
        step_down_max = value
        _sync_cast_origin()

var body: PhysicsBody3D:
    get():
        if body == null:
            var n: Node3D = get_parent_node_3d()
            while n != null && n is not PhysicsBody3D:
                n = n.get_parent_node_3d()
            
            body = n
            
        return body

var up_global: Vector3:
    get():
        var b: PhysicsBody3D = body
        if b is CharacterBody3D:
            return NodeUtils.translate_to_global_direction((b as CharacterBody3D).up_direction, b).normalized()
            
        return -basis.y

var shape_half_height: float:
    get():
        # We are going to assume that the rotation aligns with the body up
        if shape is CapsuleShape3D:
            var cs: CapsuleShape3D = shape
            return cs.height * 0.5
        elif shape is SphereShape3D:
            return (shape as SphereShape3D).radius
        elif shape is BoxShape3D:
            return (shape as BoxShape3D).size.y
        else:
            push_warning("Don't know the exact height of %s" % shape)
            return 1.0

func _ready() -> void:
    enabled = false
    _sync_cast_origin()
    
func _sync_cast_origin() -> void:
    var b: PhysicsBody3D = body
    if b == null:
        return
    
    var up_delta: Vector3 = up_global * (step_height_max + shape_half_height)    
    var dir: Vector3 = (b.global_basis.x * step_direction.x - b.global_basis.z * step_direction.y).normalized()
    
    global_position = body.global_position + up_delta + dir * step_distance
    target_position.y = -(step_height_max + step_down_max)


enum StepData { POINT, NORMAL }

func can_step_up(data: Dictionary[StepData, Vector3] = {}) -> bool:
    force_shapecast_update()
    if !is_colliding():
        return false

    var pt: Vector3 = get_collision_point(0)
    
    if body != null && (pt - body.global_position).dot(up_global) < 0:
        return false
    
    data[StepData.POINT] = pt
    data[StepData.NORMAL] = get_collision_normal(0)
    
    return true

@tool
extends ShapeCast3D
class_name PhysicsControllerStepCaster

@export var _translation_testers: Array[Node3D] = []

## Note: Normalizes and removes component parallell to up_global
@export var global_step_direction: Vector3:
    set(value):
        value -= value.project(up_global)
        global_step_direction = value.normalized()
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

@export var min_clearing_above: float = 0.2:
    set(value):
        min_clearing_above = value
        _sync_cast_origin()

@export var ignore_step_height: float = 0.05

@export var _debug_shape: MeshInstance3D

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
    if b == null || !is_instance_valid(b) || !b.is_inside_tree():
        return

    # Step checker
    var up_delta: Vector3 = up_global * (step_height_max + shape_half_height + min_clearing_above)
    global_position = b.global_position + up_delta + global_step_direction * step_distance
    target_position.y = -(step_height_max + step_down_max + min_clearing_above)

    # Sync translations checkers
    up_delta = up_global  * (step_height_max + shape_half_height)

    for tester: Node3D in _translation_testers:
        if !is_instance_valid(tester) ||  !tester.is_inside_tree():
            continue

        up_delta = tester.global_basis.y * (step_height_max + shape_half_height)
        tester.position.y = tester.to_local(up_delta + tester.global_position).y

enum StepData { POINT, NORMAL }

var _showing_debug_shape_status: bool
func display_debug_not_hitting() -> void:
    if _debug_shape != null && _showing_debug_shape_status:
        _showing_debug_shape_status = false
        await get_tree().create_timer(0.4).timeout
        if !_showing_debug_shape_status:
            _debug_shape.global_position = global_position
            var mat: StandardMaterial3D = _debug_shape.get_active_material(0)
            mat.albedo_color = Color.BLACK

func can_step(data: Dictionary[StepData, Vector3] = {}) -> bool:
    force_shapecast_update()
    if !is_colliding():
        display_debug_not_hitting()
        return false

    var pt: Vector3 = get_collision_point(0)
    if _debug_shape != null:
        _debug_shape.global_position = pt

    if body != null:
        var projection: float = (pt - body.global_position).dot(up_global)
        if projection <= ignore_step_height && projection >= -ignore_step_height || projection > step_height_max || projection < -step_down_max:
            if _debug_shape != null:
                var mat: StandardMaterial3D = _debug_shape.get_active_material(0)
                if projection <= -ignore_step_height:
                    mat.albedo_color = Color.AQUA
                elif projection <= ignore_step_height:
                    mat.albedo_color = Color.BLUE
                else:
                    mat.albedo_color = Color.RED
                _showing_debug_shape_status = true

            return false

    if _debug_shape != null:
        var mat: StandardMaterial3D = _debug_shape.get_active_material(0)
        mat.albedo_color = Color.WEB_GREEN
        _showing_debug_shape_status = true

    data[StepData.POINT] = pt
    data[StepData.NORMAL] = get_collision_normal(0)

    return true

func can_step_up(data: Dictionary[StepData, Vector3] = {}) -> bool:
    force_shapecast_update()
    if !is_colliding():
        display_debug_not_hitting()
        return false

    var pt: Vector3 = get_collision_point(0)
    if _debug_shape != null:
        _debug_shape.global_position = pt

    if body != null:
        var projection: float = (pt - body.global_position).dot(up_global)
        if projection <= ignore_step_height || projection > step_height_max:
            if _debug_shape != null:
                var mat: StandardMaterial3D = _debug_shape.get_active_material(0)
                if projection <= -ignore_step_height:
                    mat.albedo_color = Color.AQUA
                elif projection <= ignore_step_height:
                    mat.albedo_color = Color.BLUE
                else:
                    mat.albedo_color = Color.RED
                _showing_debug_shape_status = true

            return false

    if _debug_shape != null:
        var mat: StandardMaterial3D = _debug_shape.get_active_material(0)
        mat.albedo_color = Color.WEB_GREEN
        _showing_debug_shape_status = true

    data[StepData.POINT] = pt
    data[StepData.NORMAL] = get_collision_normal(0)

    return true

@tool
extends ShapeCast3D
class_name PhysicsControllerStepCaster

## Note: Normalizes and removes component parallell to up_global
@export var global_step_direction: Vector3:
    set(value):
        value -= value.project(up_global)
        global_step_direction = value.normalized()
        _sync_cast_down_origin()

@export var step_distance: float = 0.2:
    set(value):
        step_distance = value
        _sync_cast_down_origin()

@export var step_height_max: float = 0.35:
    set(value):
        step_height_max = value
        _sync_cast_down_origin()

@export var step_down_max: float = 0.35:
    set(value):
        step_down_max = value
        _sync_cast_down_origin()

@export var min_clearing_above: float = 0.8:
    set(value):
        min_clearing_above = value
        _sync_cast_down_origin()

@export var cast_height_origin: float = 0.8:
    set(value):
        cast_height_origin = value
        _sync_cast_down_origin()

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
    _sync_cast_down_origin()

func _sync_cast_down_origin() -> void:
    var b: PhysicsBody3D = body
    if b == null || !is_instance_valid(b) || !b.is_inside_tree():
        return

    global_position = (
        b.global_position +
        up_global * cast_height_origin +
        step_distance * global_step_direction
    )

    target_position.y = -(cast_height_origin + step_down_max + 0.1)
    print_debug("Testing from %s with target %s" % [position, target_position])

enum StepData { POINT, NORMAL, CENTER_POINT }

var _showing_debug_shape_status: bool
func display_debug_not_hitting() -> void:
    if _debug_shape != null && _showing_debug_shape_status:
        _showing_debug_shape_status = false
        await get_tree().create_timer(0.4).timeout
        if !_showing_debug_shape_status:
            _debug_shape.global_position = global_position
            var mat: StandardMaterial3D = _debug_shape.get_active_material(0)
            mat.albedo_color = Color.BLACK

func _set_debug_shape(color: Color, point: Vector3) -> void:
    if _debug_shape != null && is_instance_valid(_debug_shape) && _debug_shape.is_inside_tree():
        var mat: StandardMaterial3D = _debug_shape.get_active_material(0)
        mat.albedo_color = color
        _showing_debug_shape_status = true
        _debug_shape.global_position = point

func can_step(data: Dictionary[StepData, Vector3] = {}, include_flats: bool = false) -> bool:
    if body == null && !is_instance_valid(body) && !body.is_inside_tree():
        return false

    force_shapecast_update()
    if !is_colliding():
        display_debug_not_hitting()
        print_debug("Hit nothing")
        return false

    var pt: Vector3 = get_collision_point(0)

    var projection: Vector3 = (pt - global_position).project(up_global)
    var step_height: float = cast_height_origin - projection.length()

    print_debug("Step height %s" % [step_height])
    if (
        !include_flats &&
        step_height <= ignore_step_height &&
        step_height >= -ignore_step_height
    ):
        print_debug("This is flat, not a step")
        _set_debug_shape(Color.AQUA, pt)
        return false
    elif step_height < -step_down_max:
        print_debug("Too large step down %s vs %s" % [step_height, -step_down_max])
        _set_debug_shape(Color.RED, pt)
        return false
    elif step_height > step_height_max:
        print_debug("Too large step up %s vs %s" % [step_height, step_height_max])
        _set_debug_shape(Color.ORANGE, pt)
        return false

    var center_point: Vector3 = (pt - global_position).project(up_global) + global_position
    if projection.length() < min_clearing_above:
        global_position = center_point
        target_position.y = min_clearing_above
        force_shapecast_update()
        if is_colliding():
            _sync_cast_down_origin()
            return false

        _sync_cast_down_origin()

    _set_debug_shape(Color.WEB_GREEN, pt)

    data[StepData.POINT] = pt
    data[StepData.CENTER_POINT] = center_point
    data[StepData.NORMAL] = get_collision_normal(0)

    return true

func can_step_up(data: Dictionary[StepData, Vector3] = {}) -> bool:
    if can_step(data):
        return data[StepData.CENTER_POINT].y > body.global_position.y + ignore_step_height
    return false

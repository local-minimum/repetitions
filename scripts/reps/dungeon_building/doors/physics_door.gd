@abstract
extends Node3D
class_name PhysicsDoor

@export var _trigger_areas: Array[Area3D]
@export var _ignore_colliders: Array[StaticBody3D]

@abstract func _blocking_body_detected(area: Area3D, body: PhysicsBody3D) -> void
@abstract func _blocking_body_removed(area: Area3D, body: PhysicsBody3D) -> void

@abstract func _interact(interactor: Node3D) -> void

## If the door is closer to be open than closed
@abstract func is_open() -> bool

## If the door is animating / moving
@abstract func is_animating() -> bool

## If the door is animating and opening
@abstract func is_opening() -> bool

func _enter_tree() -> void:
    for _trigger_area: Area3D in _trigger_areas:
        if !_trigger_area.body_entered.is_connected(_handle_body_enter_door_trigger) && _trigger_area.body_entered.connect(_handle_body_enter_door_trigger.bind(_trigger_area)) != OK:
            push_error("Failed to connect body entered trigger area %s" % [_trigger_area])
        if !_trigger_area.body_exited.is_connected(_handle_body_exit_door_trigger) && _trigger_area.body_exited.connect(_handle_body_exit_door_trigger.bind(_trigger_area)) != OK:
            push_error("Failed to connect body exited trigger area %s" % [_trigger_area])

func _handle_body_enter_door_trigger(body: Node3D, area: Area3D) -> void:
    var b: PhysicsBody3D = NodeUtils.body3d(body)
    if b == null || _ignore_colliders.has(b):
        # print_debug("Ignoring collision with %s / %s in ignores %s" % [
        #    body, b, _ignore_colliders.has(b)
        #])
        return

    _blocking_body_detected(area, b)

func _handle_body_exit_door_trigger(body: Node3D, area: Area3D) -> void:
    var b: PhysicsBody3D = NodeUtils.body3d(body)
    if b == null || _ignore_colliders.has(b):
        # print_debug("Ignoring collision with %s / %s in ignores %s" % [
        #    body, b, _ignore_colliders.has(b)
        #])
        return

    _blocking_body_removed(area, b)

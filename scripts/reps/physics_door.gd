@abstract
extends Node3D
class_name PhysicsDoor

@export var _body: PhysicsBody3D
@export var _interaction_point: Node3D
@export var _max_interaction_distance_sq: float = 6.0
@export var _trigger_area: Area3D
@export var _ignore_colliders: Array[StaticBody3D]

@abstract func _blocking_body_detected(body: PhysicsBody3D) -> void

@abstract func _interact(interactor: Node3D) -> void

## If the door is closer to be open than closed
@abstract func is_open() -> bool

## If the door is animating / moving
@abstract func is_animating() -> bool

## If the door is animating and opening
@abstract func is_opening() -> bool

var _player: PhysicsGridPlayerController
var _hovered: bool

func _enter_tree() -> void:
    if !_body.mouse_entered.is_connected(_handle_hover_door_enter) && _body.mouse_entered.connect(_handle_hover_door_enter) != OK:
        push_error("Failed to connect mouse entered")
    if !_body.mouse_exited.is_connected(_handle_hover_door_exit) && _body.mouse_exited.connect(_handle_hover_door_exit) != OK:
        push_error("Failed to connect mouse exited")
    if !_body.input_event.is_connected(_handle_input_event) && _body.input_event.connect(_handle_input_event) != OK:
        push_error("Failed to connect input event")
    if __SignalBus.on_physics_player_ready.connect(_handle_player_ready) != OK:
        push_error("Failed to connect physics player ready")
    if _trigger_area.body_entered.is_connected(_handle_body_enter_door_trigger) && _trigger_area.body_entered.connect(_handle_body_enter_door_trigger) != OK:
        push_error("Failed to connect body entered trigger area")

func _exit_tree() -> void:
    _body.mouse_entered.disconnect(_handle_hover_door_enter)
    _body.mouse_exited.disconnect(_handle_hover_door_exit)
    _body.input_event.disconnect(_handle_input_event)
    _trigger_area.body_entered.disconnect(_handle_body_enter_door_trigger)

func with_interaction_range(interactor: Node3D) -> bool:
    # print_debug("%s in range of %s -> %s < %s" % [
    #    interactor.name,
    #    _interaction_point.name,
    #    interactor.global_position.distance_squared_to(_interaction_point.global_position),
    #    _max_interaction_distance_sq,
    # ])
    return interactor.global_position.distance_squared_to(_interaction_point.global_position) < _max_interaction_distance_sq

func _handle_player_ready(player: PhysicsGridPlayerController) -> void:
    _player = player

func _handle_hover_door_enter() -> void:
    if _player == null || !with_interaction_range(_player):
        return
    InputCursorHelper.add_state(self, InputCursorHelper.State.HOVER)
    _hovered = true
    # print_debug("Door %s can be interacted with" % name)

func _handle_hover_door_exit() -> void:
    if _hovered:
        InputCursorHelper.remove_state(self, InputCursorHelper.State.HOVER)
        _hovered = false
        # print_debug("Door %s can no longer be interacted with" % name)

func _is_mouse_click(evt: InputEvent) -> bool:
    if evt.is_echo():
        return false

    if evt is InputEventMouseButton:
        var m_evt: InputEventMouseButton = evt
        return m_evt.pressed && m_evt.button_index == MOUSE_BUTTON_LEFT

    return false

func _handle_input_event(cam: Node, evt: InputEvent, _pt: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if _player != null && _player.cinematic:
        return

    # print_debug("Door %s getting event %s while hovered %s" % [name, evt, _hovered])

    if _hovered:
        var interactor: Node3D = NodeUtils.node3d(cam)
        if interactor == null:
            return

        if evt.is_action_pressed(&"crawl_search") || _is_mouse_click(evt):
            _interact(interactor)
            get_viewport().set_input_as_handled()
        elif !with_interaction_range(interactor):
            _handle_hover_door_exit()
    else:
        _handle_hover_door_enter()

func _handle_body_enter_door_trigger(body: Node3D) -> void:
    var b: PhysicsBody3D = NodeUtils.body3d(body)
    if b == null || _ignore_colliders.has(b):
        print_debug("Ignoring collision with %s / %s in ignores %s" % [
            body, b, _ignore_colliders.has(b)
        ])
        return

    _blocking_body_detected(b)

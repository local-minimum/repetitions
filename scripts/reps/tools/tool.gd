extends Node3D
class_name Tool
enum ToolType { NONE, PICKAX, TROPHY, BLUEPRINT, KEY }

@export var _type: ToolType = ToolType.NONE
@export var _pickup_distance_sq: float = 3.0

## The collision object that outlines the interaction area of the tool
@export var _body: CollisionObject3D:
    get():
        if _body == null:
            for body: CollisionObject3D in find_children("", "CollisionObject3D"):
                _body = body
                break
        return _body

var _player: PhysicsGridPlayerController:
    get():
        if _player == null:
            return PhysicsGridPlayerController.last_connected_player
        return _player

func _enter_tree() -> void:
    if _type == ToolType.NONE:
        _body.queue_free()
    else:
        if !_body.mouse_entered.is_connected(_handle_mouse_entered) && _body.mouse_entered.connect(_handle_mouse_entered) != OK:
            push_error("Failed to connect mouse entered")
        if !_body.mouse_exited.is_connected(_handle_mouse_exited) && _body.mouse_exited.connect(_handle_mouse_exited) != OK:
            push_error("Failed to connect mouse exited")
        if !_body.input_event.is_connected(_handle_input_event) && _body.input_event.connect(_handle_input_event) != OK:
            push_error("Failed to connect mouse entered")
        if __SignalBus.on_physics_player_ready.connect(_handle_player_ready) != OK:
            push_error("Failed to connect physics player ready")
        if __SignalBus.on_physics_player_removed.connect(_handle_player_removed) != OK:
            push_error("Failed to connect physics player ready")

func _exit_tree() -> void:
    if _type != ToolType.NONE:
        __SignalBus.on_physics_player_ready.disconnect(_handle_player_ready)
        __SignalBus.on_physics_player_removed.disconnect(_handle_player_removed)

func _handle_player_ready(player: PhysicsGridPlayerController) -> void:
    _player = player

func _handle_player_removed(player: PhysicsControllerStepCaster) -> void:
    if _player == player:
        _player = null

func _handle_mouse_entered() -> void:
    if validate_player_position():
        InputCursorHelper.add_state(self, InputCursorHelper.State.HOVER)

func _handle_mouse_exited() -> void:
    InputCursorHelper.remove_state(self, InputCursorHelper.State.HOVER)

func validate_player_position(camera: Node = null) -> bool:
    if camera == null && _player != null:
        camera = _player.camera

    if camera is Camera3D:
        var cam: Camera3D = camera
        if cam.global_position.distance_squared_to(global_position) < _pickup_distance_sq:
            return true
    return false

func _handle_input_event(camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event.is_echo():
        return

    var can_pickup: bool = validate_player_position(camera)

    if event is InputEventMouseButton:
        var mouse_btn_evt: InputEventMouseButton = event
        if can_pickup && mouse_btn_evt.pressed && mouse_btn_evt.button_index == MOUSE_BUTTON_LEFT:
            __SignalBus.on_pickup_tool.emit(_type)
            InputCursorHelper.remove_node(self)
            get_viewport().set_input_as_handled()

            _do_pickup()

            queue_free()


func _do_pickup() -> void:
    pass

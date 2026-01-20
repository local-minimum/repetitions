extends Node3D
class_name PlannerTerminal

@export var _pickup_distance_sq: float = 3.0
@export var _body: CollisionObject3D:
    get():
        if _body == null:
            for body: CollisionObject3D in find_children("", "CollisionObject3D"):
                _body = body
                break
        return _body
@export var _interaction_direction_reference: Node3D
@export var _interaction_angle_threshold: float = 0.5
@export var _plans_for_relative_elevation: int = 0
var _player: PhysicsGridPlayerController

func _enter_tree() -> void:
    if !_body.mouse_entered.is_connected(_handle_mouse_entered) && _body.mouse_entered.connect(_handle_mouse_entered) != OK:
        push_error("Failed to connect mouse entered")
    if !_body.mouse_exited.is_connected(_handle_mouse_exited) && _body.mouse_exited.connect(_handle_mouse_exited) != OK:
        push_error("Failed to connect mouse exited")    
    if !_body.input_event.is_connected(_handle_input_event) && _body.input_event.connect(_handle_input_event) != OK:
        push_error("Failed to connect mouse entered")    
    if __SignalBus.on_physics_player_ready.connect(_handle_player_ready) != OK:
        push_error("Failed to connect physics player ready")

func _exit_tree() -> void:
    _body.mouse_entered.disconnect(_handle_mouse_entered)
    _body.mouse_exited.disconnect(_handle_mouse_exited)
    _body.input_event.disconnect(_handle_input_event)
    __SignalBus.on_physics_player_ready.disconnect(_handle_player_ready)
    
func _handle_player_ready(player: PhysicsGridPlayerController) -> void:
    _player = player
    
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
            var d: Vector3 = (_interaction_direction_reference.global_position - _body.global_position).normalized()
            var cam_forward: Vector3 = -cam.global_basis.z
            
            print_debug("%s vs %s -> %s < %s" % [
                cam_forward, d, cam_forward.dot(d), _interaction_angle_threshold
            ])
            return cam_forward.dot(d) > _interaction_angle_threshold      
            
    return false
                   
func _handle_input_event(camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event.is_echo():
        return

    if event is InputEventMouseButton:
        var mouse_btn_evt: InputEventMouseButton = event
        if validate_player_position(camera) && mouse_btn_evt.pressed && mouse_btn_evt.button_index == MOUSE_BUTTON_LEFT:
            var builder: DungeonBuilder = DungeonBuilder.find_builder_in_tree(self)
            var coords: Vector3i = builder.get_coordinates(global_position)
            __SignalBus.on_ready_planner.emit(_player, coords.y + _plans_for_relative_elevation)

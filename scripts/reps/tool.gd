extends Node3D
class_name Tool
enum ToolType { NONE, PICKAX }

@export var _type: ToolType = ToolType.NONE
@export var _pickup_distance_sq: float = 3.0

@export var _body: CollisionObject3D:
    get():
        if _body == null:
            for body: CollisionObject3D in find_children("", "CollisionObject3D"):
                _body = body
                break
        return _body

func _enter_tree() -> void:
    if !_body.mouse_entered.is_connected(_handle_mouse_entered) && _body.mouse_entered.connect(_handle_mouse_entered) != OK:
        push_error("Failed to connect mouse entered")
    if !_body.mouse_exited.is_connected(_handle_mouse_exited) && _body.mouse_exited.connect(_handle_mouse_exited) != OK:
        push_error("Failed to connect mouse exited")    
    if !_body.input_event.is_connected(_handle_input_event) && _body.input_event.connect(_handle_input_event) != OK:
        push_error("Failed to connect mouse entered")    

func _exit_tree() -> void:
    _body.mouse_entered.disconnect(_handle_mouse_entered)
    _body.mouse_exited.disconnect(_handle_mouse_exited)
    _body.input_event.disconnect(_handle_input_event)
    
func _handle_mouse_entered() -> void:
    InputCursorHelper.add_state(self, InputCursorHelper.State.HOVER)

func _handle_mouse_exited() -> void:
    InputCursorHelper.remove_state(self, InputCursorHelper.State.HOVER)
    
func _handle_input_event(camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event.is_echo():
        return
        
    var can_pickup: bool = false
    
    if camera is Camera3D:
        var cam: Camera3D = camera
        if cam.global_position.distance_squared_to(event_position) < _pickup_distance_sq:
            can_pickup = true
    
    if event is InputEventMouseButton:
        var mouse_btn_evt: InputEventMouseButton = event
        if can_pickup && mouse_btn_evt.pressed && mouse_btn_evt.button_index == MOUSE_BUTTON_LEFT:
            __SignalBus.on_pickup_tool.emit(_type)
            queue_free()

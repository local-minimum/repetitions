extends Recepticle

@export var _terminal: PlannerTerminal
@export var _lid: Node3D
@export var _open_angle: float = -141.9
@export var _lid_tween_duration: float = 1.0
@export var _max_interact_range_sq: float = 4
@export var _trophy: Node3D

var _lid_open: bool = false
var _lid_tween: Tween

enum TrophyState { DEFAULT, RECEIVED, STOLEN }
var _trophy_state: TrophyState = TrophyState.DEFAULT

func _ready() -> void:
    _sync_trophy()
    
func _sync_trophy() -> void:
    if _trophy_state == TrophyState.RECEIVED:
        _trophy.show()
    else:
        _trophy.hide()
    
func _on_static_body_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event.is_echo():
        return
    
    if event is InputEventMouseButton:
        var mbtn_evt: InputEventMouseButton = event
        if mbtn_evt.pressed && mbtn_evt.button_index == MOUSE_BUTTON_LEFT && _in_range(camera, event_position):
            _toggle_lid()
            get_viewport().set_input_as_handled()

func _in_range(camera: Node, event_position: Vector3) -> bool:
    if camera is Node3D:
        var n: Node3D = camera
        return n.global_position.distance_squared_to(event_position) < _max_interact_range_sq
    
    return false

func _toggle_lid() -> void:
    if _lid == null:
        return

    if _lid_tween != null && _lid_tween.is_running():
        _lid_tween.kill()
        
    _lid_tween = create_tween()                
    @warning_ignore_start("return_value_discarded")
    _lid_tween.tween_property(_lid, "rotation_degrees:y", _open_angle if !_lid_open else 0.0, _lid_tween_duration)
    @warning_ignore_restore("return_value_discarded")

    _lid_open = !_lid_open


func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event.is_echo():
        return
    
    if event is InputEventMouseButton:
        var mbtn_evt: InputEventMouseButton = event
        if mbtn_evt.pressed && mbtn_evt.button_index == MOUSE_BUTTON_LEFT && _in_range(camera, event_position):
            if _trophy_state == TrophyState.DEFAULT:
                __SignalBus.on_request_tool.emit(Tool.ToolType.TROPHY, self)
                
            elif _trophy_state == TrophyState.RECEIVED:
                _terminal.trophy_bonus = 0
                _trophy_state = TrophyState.STOLEN if _terminal.is_overused else TrophyState.DEFAULT
                _trophy.hide()
                __SignalBus.on_pickup_tool.emit(Tool.ToolType.TROPHY)
            
            get_viewport().set_input_as_handled()


func receive(tool_type: Tool.ToolType) -> bool:
    if tool_type != Tool.ToolType.TROPHY:
        return false
        
    if _trophy_state == TrophyState.DEFAULT:
        _terminal.trophy_bonus = 1
        _trophy_state = TrophyState.RECEIVED
        _trophy.show()
        return true
         
    return false

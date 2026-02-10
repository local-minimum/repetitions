extends Recepticle

@export var _terminal: PlannerTerminal
@export var _lid: Node3D
@export var _open_angle: float = -141.9
@export var _lid_tween_duration: float = 1.0
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

func _execute_interaction() -> void:
    if _trophy_state == TrophyState.DEFAULT:
        __SignalBus.on_request_tool.emit(Tool.ToolType.TROPHY, self)

    elif _trophy_state == TrophyState.RECEIVED:
        _terminal.trophy_bonus = 0
        _trophy_state = TrophyState.STOLEN if _terminal.is_overused else TrophyState.DEFAULT
        _trophy.hide()
        __SignalBus.on_pickup_tool.emit(Tool.ToolType.TROPHY)
        if _trophy_state == TrophyState.STOLEN:
            __SignalBus.on_trophy_stolen_from_terminal.emit(_terminal)

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

func receive(tool_type: Tool.ToolType) -> bool:
    if tool_type != Tool.ToolType.TROPHY:
        return false

    if _trophy_state == TrophyState.DEFAULT:
        _terminal.trophy_bonus = 1
        _trophy_state = TrophyState.RECEIVED
        _trophy.show()
        return true

    return false

func _on_static_body_3d_execute_interaction() -> void:
    _toggle_lid()

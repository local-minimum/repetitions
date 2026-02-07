extends Tool
class_name ToolBlueprint

enum Blueprint { NONE, REACTOR }

@export var _blueprint: Blueprint = Blueprint.NONE

func _do_pickup() -> void:
    if _blueprint != Blueprint.NONE:
        __SignalBus.on_pickup_tool_blueprint.emit(_blueprint)

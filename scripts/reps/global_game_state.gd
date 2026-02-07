extends GlobalGameStateCore
class_name GlobalGameState

func _enter_tree() -> void:
    if __SignalBus.on_pickup_tool_blueprint.connect(_handle_pickup_tool_blueprint) != OK:
        push_error("Failed to connect pickup tool blueprint")


var added_blueprints: Array[ToolBlueprint.Blueprint]

func _handle_pickup_tool_blueprint(blueprint: ToolBlueprint.Blueprint) -> void:
    if !added_blueprints.has(blueprint) && blueprint != ToolBlueprint.Blueprint.NONE:
        added_blueprints.append(blueprint)

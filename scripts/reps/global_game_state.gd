extends GlobalGameStateCore
class_name GlobalGameState

func _enter_tree() -> void:
    if __SignalBus.on_pickup_tool_blueprint.connect(_handle_pickup_tool_blueprint) != OK:
        push_error("Failed to connect pickup tool blueprint")
    if __SignalBus.on_pickup_tool_key.connect(_handle_pickup_key) != OK:
        push_error("Failed to connect pickup tool key")

var added_blueprints: Array[ToolBlueprint.Blueprint]
var collected_keys: Array[ToolKey.KeyVariant]

func _handle_pickup_tool_blueprint(blueprint: ToolBlueprint.Blueprint) -> void:
    if !added_blueprints.has(blueprint) && blueprint != ToolBlueprint.Blueprint.NONE:
        added_blueprints.append(blueprint)

func _handle_pickup_key(key: ToolKey.KeyVariant) -> void:
    if !collected_keys.has(key) && key != ToolKey.KeyVariant.NONE:
        collected_keys.append(key)

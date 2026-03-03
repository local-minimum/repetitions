extends Node3D
class_name Tool
enum ToolType { NONE, PICKAX, TROPHY, BLUEPRINT, KEY, LOOSE_TRACK }

@export var _type: ToolType = ToolType.NONE
@export var _interaction_body: InteractionBody3D
@export var _autofree: bool = true

func _enter_tree() -> void:
    if _type == ToolType.NONE:
        _interaction_body.queue_free()
    if (
        _interaction_body != null &&
        !_interaction_body.execute_interaction.is_connected(_on_static_body_3d_execute_interaction) &&
        _interaction_body.execute_interaction.connect(_on_static_body_3d_execute_interaction) != OK
    ):
        push_error("Failed to connect execute interaction")

func _on_static_body_3d_execute_interaction() -> void:
    __SignalBus.on_pickup_tool.emit(_type)
    _do_pickup()
    if _autofree:
        queue_free()

func _do_pickup() -> void:
    pass

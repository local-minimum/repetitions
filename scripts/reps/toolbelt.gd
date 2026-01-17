extends Node3D

@export var _tool_lookup: Dictionary[Tool.ToolType, EquippedTool]

var _active_tool: EquippedTool

func _enter_tree() -> void:
    if __SignalBus.on_pickup_tool.connect(_handle_pickup_tool) != OK:
        push_error("Failed to connect tool pickup")

func _exit_tree() -> void:
    __SignalBus.on_pickup_tool.disconnect(_handle_pickup_tool)

func _handle_pickup_tool(tool_type: Tool.ToolType) -> void:
    print_debug("Picked up %s " % [Tool.ToolType.find_key(tool_type)])
    if _tool_lookup.has(tool_type):
        if _active_tool != null:
            _active_tool.enabled = false
        
        _active_tool = _tool_lookup[tool_type]
        _active_tool.enabled = true

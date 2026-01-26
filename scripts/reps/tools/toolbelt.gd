extends Node3D

@export var _tool_lookup: Dictionary[Tool.ToolType, EquippedTool]

var _active_tool: EquippedTool
var _trophies: int

func _enter_tree() -> void:
    if __SignalBus.on_pickup_tool.connect(_handle_pickup_tool) != OK:
        push_error("Failed to connect tool pickup")
    if __SignalBus.on_request_tool.connect(_handle_request_tool) != OK:
        push_error("Failed to connect request tool")
    

func _exit_tree() -> void:
    __SignalBus.on_pickup_tool.disconnect(_handle_pickup_tool)
    __SignalBus.on_request_tool.disconnect(_handle_request_tool)
    
func _handle_request_tool(tool_type: Tool.ToolType, reciever: Node3D) -> void:
    if tool_type == Tool.ToolType.TROPHY:
        if _trophies <= 0:
            return
            
        _attempt_give_tool(tool_type, reciever)
        return

    if _tool_lookup.has(tool_type) && _tool_lookup[tool_type] == _active_tool:
        _attempt_give_tool(tool_type, reciever)

func _attempt_give_tool(tool_type: Tool.ToolType, reciever: Node3D) -> void:
    if reciever is Recepticle:
        var r: Recepticle = reciever
        if r.receive(tool_type):
            _trophies -= 1
            __SignalBus.on_drop_tool.emit(tool_type)
    else:
        # TODO: Handle receiving tool to the floor?
        pass
    return
              
func _handle_pickup_tool(tool_type: Tool.ToolType) -> void:
    print_debug("Picked up %s " % [Tool.ToolType.find_key(tool_type)])
    if tool_type == Tool.ToolType.TROPHY:
        _trophies += 1
        return
        
    if _tool_lookup.has(tool_type):
        if _active_tool != null:
            _active_tool.enabled = false
        
        _active_tool = _tool_lookup[tool_type]
        _active_tool.enabled = true

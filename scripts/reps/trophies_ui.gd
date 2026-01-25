extends Control

@export var _text: Label

var _count: int = 0

func _enter_tree() -> void:
    if __SignalBus.on_pickup_tool.connect(_handle_pickup_tool) != OK:
        push_error("Failed to connect pickup tool")
    if __SignalBus.on_drop_tool.connect(_handle_drop_tool) != OK:
        push_error("Failed to connect drop tool")

func _exit_tree() -> void:
    __SignalBus.on_pickup_tool.disconnect(_handle_pickup_tool)
    __SignalBus.on_drop_tool.disconnect(_handle_drop_tool)
    
func _handle_drop_tool(tool: Tool.ToolType) -> void:
    if tool == Tool.ToolType.TROPHY:
        _count = maxi(0, _count - 1)
        _text.text = "%s x" % _count
        if _count == 0:
            hide()
            
func _handle_pickup_tool(tool: Tool.ToolType) -> void:
    if tool == Tool.ToolType.TROPHY:
        _count += 1
        _text.text = "%s x" % _count
        show()

func _ready() -> void:
    hide()

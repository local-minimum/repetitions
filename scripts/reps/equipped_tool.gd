extends Node3D
class_name EquippedTool

var enabled: bool:
    set(value):
        if value:
            show()
        else:
            hide()
        enabled = value
        
func _ready() -> void:
    enabled = false

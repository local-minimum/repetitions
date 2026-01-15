extends CanvasLayer

@export var planner: DungeonPlanner


func _on_layout_done_btn_pressed() -> void:
    hide()
    __SignalBus.on_complete_dungeon_plan.emit()

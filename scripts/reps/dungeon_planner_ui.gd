extends CanvasLayer

var _planner: DungeonPlanner
@export var counter_label: Label

func _enter_tree() -> void:
    if __SignalBus.on_update_planning.connect(_handle_update_planner) != OK:
        push_error("Failed to connect update planning")

func _exit_tree() -> void:
    __SignalBus.on_update_planning.disconnect(_handle_update_planner)
    
func _on_layout_done_btn_pressed() -> void:
    _planner.complete_planning()
    
func _handle_update_planner(planner: DungeonPlanner, remaining: int) -> void:
    _planner = planner
    if counter_label == null:
        return
    
    counter_label.text = tr("UI_REMAINING_COUNT").format({"remaining_count": remaining})

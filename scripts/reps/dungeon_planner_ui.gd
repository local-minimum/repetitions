extends CanvasLayer

const _SEALED_ELEVATION_MESSAGE_ID: String = "UI_ELEVATION_SEALED"

var _planner: DungeonPlanner
@export var counter_label: Label
@export var message_label: Label

func _enter_tree() -> void:
    if __SignalBus.on_update_planning.connect(_handle_update_planner) != OK:
        push_error("Failed to connect update planning")
    if __SignalBus.on_elevation_plan_sealed.connect(_handle_elevation_plan_sealed) != OK:
        push_error("Failed to connect elevation plan sealed")

func _exit_tree() -> void:
    __SignalBus.on_update_planning.disconnect(_handle_update_planner)
    __SignalBus.on_elevation_plan_sealed.disconnect(_handle_elevation_plan_sealed)
    
func _on_layout_done_btn_pressed() -> void:
    _planner.complete_planning()

var _sealed_elevations: Array[int]

func _handle_elevation_plan_sealed(elevation: int) -> void:
    if !_sealed_elevations.has(elevation):
        _sealed_elevations.append(elevation)

    message_label.text = tr(_SEALED_ELEVATION_MESSAGE_ID)
    
func _handle_update_planner(planner: DungeonPlanner, remaining: int) -> void:
    _planner = planner
    if _sealed_elevations.has(planner.elevation):
        message_label.text = tr(_SEALED_ELEVATION_MESSAGE_ID)
    else:
        message_label.text = ""
        
    if counter_label == null:
        return
    
    counter_label.text = tr("UI_REMAINING_COUNT").format({"remaining_count": remaining})

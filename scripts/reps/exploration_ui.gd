extends CanvasLayer

func _enter_tree() -> void:
    if __SignalBus.on_ready_planner.connect(_handle_ready_planning) != OK:
        push_error("Failed to oconnect ready planner")
    if __SignalBus.on_complete_dungeon_plan.connect(_handle_complete_dungeon_plan) != OK:
        push_error("Failed to connect complete dungeon plan")

func _exit_tree() -> void:
    __SignalBus.on_ready_planner.disconnect(_handle_ready_planning)
    __SignalBus.on_complete_dungeon_plan.disconnect(_handle_complete_dungeon_plan)
    
func _handle_ready_planning(_term: PlannerTerminal, _player: PhysicsGridPlayerController, _elev: int, _allowance: int) -> void:
    hide()

func _handle_complete_dungeon_plan(_elev: int, _rooms: Array[BlueprintRoom]) -> void:
    show()

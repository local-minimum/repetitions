extends Node
class_name MovementPlanningCoordinator

@export var planners: Array[MovementPlannerBase]
@export var priority: int = 1

func _enter_tree() -> void:
    if __SignalBus.on_move_plan.connect(_handle_move_plan) != OK:
        push_error("Cannot connect to move plan")

func _exit_tree() -> void:
    __SignalBus.on_move_plan.disconnect(_handle_move_plan)

func _get_planner(entity: GridEntity) -> MovementPlannerBase:
    for planner: MovementPlannerBase in planners:
        if planner.plans_for(entity):
            return planner

    return null

func _handle_update_animation_speed(entity: GridEntity, speed: float) -> void:
    var planner: MovementPlannerBase = _get_planner(entity)
    if planner is MovementPlanner:
        var mplanner: MovementPlanner = planner
        mplanner._settings.animation_speed = speed
        __SignalBus.on_update_animation_speed.emit(mplanner._filter.type, speed)

func _handle_move_plan(entity: GridEntity, movement: Movement.MovementType) -> void:
    var planner: MovementPlannerBase = _get_planner(entity)
    if planner == null:
        push_error("No planner exists to allow %s to move" % entity)
        return

    var plan: MovementPlannerBase.MovementPlan = planner.create_plan(entity, movement)
    if plan == null:
        plan = planner.create_no_movement(entity, movement)

    if plan != null:
        if !entity.has_conflicting_plan(plan, priority):
            entity.execute_plan(plan, priority, entity.count_active_plans())

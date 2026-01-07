extends GridNodeFeature
class_name GridEntity


const _LOOK_DIRECTION_KEY: String = "look_direction"
const _DOWN_KEY: String = "down"
const _ANCHOR_KEY: String = "anchor"
const _COORDINATES_KEY: String = "coordinates"

var _old_look_direction: CardinalDirections.CardinalDirection
var _old_down: CardinalDirections.CardinalDirection
var _emit_orientation: bool

## If cinematic, AI or player shouldn't be allowed to do inputs
var _cinematics: Array[Node]
var cinematic: bool:
    get():
        return !_cinematics.is_empty()

    set (value):
        if value:
            cause_cinematic(self)
        else:
            remove_cinematic_cause(self)

        push_warning("%s is cinematic %s due to unspecific cause" % [name, cinematic])

func cause_cinematic(cause: Node) -> void:
    if cause == null || _cinematics.has(cause):
        return
    _cinematics.append(cause)
    if _cinematics.size() == 1:
        __SignalBus.on_cinematic.emit(self, true)
        clear_queue()

func remove_cinematic_cause(cause: Node) -> void:
    if _cinematics.is_empty():
        return

    _cinematics.erase(cause)
    if _cinematics.is_empty():
        __SignalBus.on_cinematic.emit(self, false)

var occupying_space: bool = true

## Mid/core of entity
@export var center: Node3D:
    get():
        if center == null:
            return self
        return center

@export var look_direction: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.NORTH:
    set(value):
        _old_look_direction = look_direction
        _emit_orientation = true
        look_direction = value
        await get_tree().physics_frame
        delay_emit()

@export var down: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.DOWN:
    set(value):
        _old_down = down
        _emit_orientation = true
        down = value
        await get_tree().physics_frame
        delay_emit()

@export var transportation_mode: TransportationMode
var transportation_ability_override: TransportationMode
@export var transportation_abilities: TransportationMode:
    get():
        if transportation_ability_override != null:
            return transportation_ability_override
        return transportation_abilities

@export var can_jump_off_floor: bool:
    get():
        return can_jump_off_floor || can_jump_off_all

@export var can_jump_off_all: bool
@export var orient_with_gravity_in_air: bool = true

@export var executor: MovementExecutor

@export var concurrent_turns: bool

@export var queue_moves: bool = true

@export var _spawn_node: GridNode
@export var _spawn_anchor_direction: CardinalDirections.CardinalDirection = CardinalDirections.CardinalDirection.NONE

var _next_movement: Movement.MovementType = Movement.MovementType.NONE
var _next_next_movement: Movement.MovementType = Movement.MovementType.NONE

func _ready() -> void:
    sync_spawn()
    get_level().grid_entities.append(self)

func sync_spawn() -> void:
    if _spawn_node != null:
        var spawn_anchor: GridAnchor = _spawn_node.get_grid_anchor(_spawn_anchor_direction)
        update_entity_anchorage(_spawn_node, spawn_anchor)
        sync_position()

    orient(self)

func load_look_direction_and_down(load_look: CardinalDirections.CardinalDirection, load_down: CardinalDirections.CardinalDirection) -> void:
    look_direction = load_look
    _old_look_direction = CardinalDirections.CardinalDirection.NONE

    down = load_down
    _old_down = CardinalDirections.CardinalDirection.NONE

func delay_emit() -> void:
    if CardinalDirections.is_parallell(down, look_direction):
        push_error("[Entity %s] Has colinear look (%s) and down (%s)" % [
            name,
            CardinalDirections.name(look_direction),
            CardinalDirections.name(down),
        ])

    if _emit_orientation:
        _emit_orientation = false
        __SignalBus.on_update_orientation.emit(self, _old_down, down, _old_look_direction, look_direction)
        _old_down = down
        _old_look_direction = look_direction

func is_moving() -> bool:
    return count_active_plans() > 0

var _block_concurrent: bool

func block_concurrent_movement() -> void:
    _block_concurrent = true

func remove_concurrent_movement_block() -> void:
    _block_concurrent = false

var _active_plans: Dictionary[MovementPlannerBase.MovementPlan, int] = {}

func count_active_plans() -> int:
    var now: int = Time.get_ticks_msec()
    for plan: MovementPlannerBase.MovementPlan in _active_plans.keys():
        if plan.end_time_msec < now:
            @warning_ignore_start("return_value_discarded")
            _active_plans.erase(plan)
            @warning_ignore_restore("return_value_discarded")

    return _active_plans.size()

func _superseeded_plans(
    plan: MovementPlannerBase.MovementPlan,
    priority: int,
) -> Array[MovementPlannerBase.MovementPlan]:
    var conflicts: Array[MovementPlannerBase.MovementPlan]
    var is_translation: bool = MovementPlannerBase.is_translation_plan(plan)
    var is_rotation: bool = MovementPlannerBase.is_rotation_plan(plan)
    var now: int = Time.get_ticks_msec()
    for active: MovementPlannerBase.MovementPlan in _active_plans:
        if active.end_time_msec < now:
            continue

        var active_should_be_replaced: bool = _active_plans[active] <= priority
        if !concurrent_turns && active_should_be_replaced:
            conflicts.append(active)
        elif is_translation && MovementPlannerBase.is_translation_plan(active):
            if !active_should_be_replaced:
                conflicts.append(active)
        elif is_rotation && MovementPlannerBase.is_rotation_plan(active):
            if !active_should_be_replaced:
                conflicts.append(active)

    return conflicts

func has_conflicting_plan(
    plan: MovementPlannerBase.MovementPlan,
    priority: int,
) -> bool:
    var is_translation: bool = MovementPlannerBase.is_translation_plan(plan)
    var is_rotation: bool = MovementPlannerBase.is_rotation_plan(plan)
    var now: int = Time.get_ticks_msec()

    for active: MovementPlannerBase.MovementPlan in _active_plans:
        if active.end_time_msec < now:
            continue

        var active_has_prio: bool = _active_plans[active] > priority
        if !concurrent_turns && active_has_prio:
            return true
        elif is_translation && MovementPlannerBase.is_translation_plan(active):
            if !active_has_prio:
                return true
        elif is_rotation && MovementPlannerBase.is_rotation_plan(active):
            if !active_has_prio:
                return true

    return false

func _executing_conflicting_plan(
    movement: Movement.MovementType,
) -> bool:
    var is_translation: bool = Movement.is_translation(movement)
    var is_rotation: bool = Movement.is_turn(movement)
    var now: int = Time.get_ticks_msec()

    for active: MovementPlannerBase.MovementPlan in _active_plans:
        if active.end_time_msec < now:
            continue

        if !concurrent_turns:
            if _debug:
                print_debug("[Grid Entity %s] does not allow concurrent plans and %s among %s is active" % [
                    name,
                    active,
                    _active_plans,
                ])
            return true

        elif is_translation && MovementPlannerBase.is_translation_plan(active):
            if _debug:
                print_debug("[Grid Entity %s] does not allow %s as %s is active and translating" % [
                    name,
                    Movement.name(movement),
                    active.summarize(),
                ])
            return true

        elif is_rotation && MovementPlannerBase.is_rotation_plan(active):
            if _debug:
                print_debug("[Grid Entity %s] does not allow %s as %s is active and rotating" % [
                    name,
                    Movement.name(movement),
                    active.summarize(),
                ])
            return true

    return false

func execute_plan(plan: MovementPlannerBase.MovementPlan, priority: int, concurrent: bool) -> void:
    for existing: MovementPlannerBase.MovementPlan in _superseeded_plans(plan, priority):
        if existing.equals(plan):
            if _debug:
                print_debug("[Grid Entity %s] Ignoring plan %s because equivalent to %s" % [
                    name,
                    plan.summarize(),
                    existing.summarize(),
                ])
            return

        executor.abort_plan(plan)
        @warning_ignore_start("return_value_discarded")
        _active_plans.erase(plan)
        @warning_ignore_restore("return_value_discarded")

    _active_plans[plan] = priority
    executor.execute_plan(plan, priority, concurrent)

func force_movement(movement: Movement.MovementType) -> bool:
    if _can_execute_movement(movement, true):
        return attempt_movement(movement, false, true)
    return false

func _can_execute_movement(movement: Movement.MovementType, force: bool) -> bool:
    if Movement.MovementType.NONE == movement || (cinematic || falling()) && !force:
        push_warning("[Grid Entity %s] Movement refused: not accepting movements [cinematic = %s, falling = %s]" % [
            name,
            cinematic,
            falling(),
        ])
        return false

    return force || !_executing_conflicting_plan(movement)

func complete_plan(plan: MovementPlannerBase.MovementPlan, continue_with_next: bool = true) -> void:
    @warning_ignore_start("return_value_discarded")
    _active_plans.erase(plan)
    @warning_ignore_restore("return_value_discarded")

    if count_active_plans() == 0:
        if _debug:
            print_debug("[Grid Entity %s] Ended all movements" % [
                name,
            ])

        __SignalBus.on_move_end.emit(self)

        if continue_with_next:
            _attempt_movement_from_queue()

func _attempt_movement_from_queue() -> void:
    if !queue_moves:
        return

    if _next_movement != Movement.MovementType.NONE:
        if attempt_movement(_next_movement, false):
            _next_movement = _next_next_movement
            _next_next_movement = Movement.MovementType.NONE
        else:
            clear_queue()
            print_debug("Queued movement refused")

func falling() -> bool:
    return transportation_mode.mode == TransportationMode.FALLING

func duck() -> void:
    pass

func stand_up() -> void:
    pass

func attempt_movement(
    movement: Movement.MovementType,
    enqueue_if_occupied: bool = true,
    force: bool = false,
) -> bool:
    if _debug:
        print_debug("[Grid Entity %s] Attempt movement %s from %s" % [name, Movement.name(movement), coordinates()])

    if get_level().paused:
        if _debug:
            print_debug("[Grid Entity %s] Ignoring movement %s because level is paused" % [name, Movement.name(movement)])
        return false

    if movement == Movement.MovementType.NONE:
        push_error("[Grid Entity %s] Ignoring movement %s it isn't a movement" % [name, Movement.name(movement)])
        print_stack()
        return false

    if !_can_execute_movement(movement, force):
        if _debug:
            print_debug("[Grid Entity %s] Movement %s not allowed at this time" % [name, Movement.name(movement)])
        if enqueue_if_occupied && queue_moves:
            _enqeue_movement(movement)
            return true

        return false

    if force:
        clear_queue()

    __SignalBus.on_move_plan.emit(self, movement)
    return true

func _enqeue_movement(movement: Movement.MovementType) -> void:
    if _next_movement != Movement.MovementType.NONE:
        _next_next_movement = movement
        # print_debug("%s enqued as next next movement (%s next)" % [
            # Movement.name(movement),
            # Movement.name(_next_movement),
        # ])
        return

    _next_movement = movement
    # print_debug("%s enqued as next movement" % [
        # Movement.name(_next_movement),
    # ])

## Empties queued up moves
func clear_queue() -> void:
    _next_movement = Movement.MovementType.NONE
    _next_next_movement = Movement.MovementType.NONE

func update_entity_anchorage(new_node: GridNode, new_anchor: GridAnchor, deferred: bool = false) -> void:
    if new_anchor != null:
        set_grid_anchor(new_anchor, deferred)
        if transportation_abilities != null:
            transportation_mode.mode = transportation_abilities.intersection(new_anchor.required_transportation_mode)
    else:
        set_grid_node(new_node, deferred)
        if transportation_abilities != null:
            if cinematic || transportation_abilities.has_flag(TransportationMode.FLYING):
                transportation_mode.mode = TransportationMode.FLYING
            else:
                transportation_mode.mode = TransportationMode.FALLING
    
    if _debug:
        print_debug("[Grid Entity %s] Now %s @ %s %s" % [name, transportation_mode.humanize() if transportation_mode != null else "static", new_node.name, CardinalDirections.name(new_anchor.direction) if new_anchor else "airbourne"])

func sync_position() -> void:
    if anchor != null:
        global_position = anchor.global_position
        return

    var node: GridNode = get_grid_node()
    if node != null:
        global_position = GridNode.get_center_pos(node, node.level)
        return

    push_error("%s doesn't have either a node or anchor set" % name)
    print_stack()


static func orient(entity: GridEntity) -> void:
    if entity.look_direction == CardinalDirections.CardinalDirection.NONE || entity.down == CardinalDirections.CardinalDirection.NONE:
        push_warning("Cannot orient %s looking %s and down %s" % [
            entity.name,
            CardinalDirections.name(entity.look_direction),
            CardinalDirections.name(entity.down)
        ])
        return

    entity.look_at(
        entity.global_position + Vector3(CardinalDirections.direction_to_vectori(entity.look_direction)),
        CardinalDirections.direction_to_vectori(CardinalDirections.invert(entity.down)),
    )

static func sync_entity_position(entity: GridEntity) -> void:
    if entity.anchor != null:
        entity.global_position = entity.anchor.global_position
        return

    var node: GridNode = entity.get_grid_node()
    if node != null:
        entity.global_position = GridNode.get_center_pos(node, node.level)
        return

    push_error("%s doesn't have either a node or anchor set" % entity.name)
    print_stack()

static func find_entity_parent(current: Node, inclusive: bool = true) ->  GridEntity:
    if inclusive && current is GridEntity:
        return current as GridEntity

    if current == null:
        return null

    var parent: Node = current.get_parent()

    if parent == null:
        return null

    if parent is GridEntity:
        return parent as GridEntity

    return find_entity_parent(parent, false)

extends Node
class_name DraftPool

@export var _start_rooms: Array[DraftOption]
@export var pool: Array[DraftOption]
@export var _addables: Dictionary[ToolBlueprint.Blueprint, DraftOption]

func _enter_tree() -> void:
    if __SignalBus.on_pickup_tool_blueprint.connect(_handle_pickup_tool_blueprint) != OK:
        push_error("Failed to connect pickup tool blueprint")

func _ready() -> void:
    for opt: DraftOption in pool:
        opt.drafted_count = 0

    for blueprint: ToolBlueprint.Blueprint in __GlobalGameState.added_blueprints:
        _handle_pickup_tool_blueprint(blueprint)

    validate_integrity()

var _exp: RegEx = RegEx.new()
var _exp_compiled: bool

func _handle_pickup_tool_blueprint(blueprint: ToolBlueprint.Blueprint) -> void:
    if _addables.has(blueprint):
        var opt: DraftOption = _addables.get(blueprint)
        if opt != null && !pool.has(opt):
            opt.drafted_count = 0
            pool.append(opt)
            print_debug("Adding %s to %s due to picking up %s" % [opt, pool, ToolBlueprint.Blueprint.find_key(blueprint)])
        elif opt == null:
            push_error("There was a null room draft option in the addables for %s" % [ToolBlueprint.Blueprint.find_key(blueprint)])
        else:
            push_error("There already was a %s in %s for %s" % [
                opt,
                pool,
                ToolBlueprint.Blueprint.find_key(blueprint)
            ])
    else:
        push_warning("We don't know of blueprint %s, only %s" % [ToolBlueprint.Blueprint.find_key(blueprint), _addables])

func validate_integrity() -> void:
    var ids: Dictionary[DraftOption.RoomId, DraftOption]
    var paths: Dictionary[String, DraftOption]

    for opt: DraftOption in _start_rooms:
        _validate_option(opt, ids, paths)

    for opt: DraftOption in pool:
        _validate_option(opt, ids, paths)

func _validate_option(
    opt: DraftOption,
    ids: Dictionary[DraftOption.RoomId, DraftOption],
    paths: Dictionary[String, DraftOption],
) -> void:
    if !_exp_compiled:
        if _exp.compile("^[A-Z_]+$") != OK:
            push_error("Failed to compile regex")
            _exp_compiled = true

    var errs: Array[String]

    # 1. Check IDs
    if opt.room_id == DraftOption.RoomId.UNKNOWN:
        errs.append("Room lacks ID")
    elif ids.has(opt.room_id):
        errs.append("ID collides with %s" % ids[opt.room_id].resource_path)
    else:
        ids[opt.room_id] = opt

    # 2. Check 2d path:
    if paths.has(opt._blueprint_room_path):
        errs.append("2d blueprint scene is same as in %s" % paths[opt._blueprint_room_path].resource_path)
    else:
        paths[opt._blueprint_room_path] = opt

    # 3. Check 3d path:
    if paths.has(opt._3d_room_path):
        errs.append("3d scene is same as in" % paths[opt._3d_room_path].resource_path)
    else:
        paths[opt._3d_room_path] = opt

    # 4. Room name key:
    if opt.room_name_key.is_empty():
        errs.append("Lacking translation key")
    elif _exp_compiled && _exp.search(opt.room_name_key) == null:
        errs.append("Malformed translation key '%s'" % opt.room_name_key)
    elif tr(opt.room_name_key) == opt.room_name_key:
        errs.append("Missing translation key for '%s'" % opt.room_name_key)

    if !errs.is_empty():
        push_error("%s has the following errors: %s" % [opt.resource_path, errs])

func draft(count: int = 1) -> Array[DraftOption]:
    var available: Array[DraftOption] = Array(
        pool.filter(func (opt: DraftOption) -> bool: return !opt.consumed),
        TYPE_OBJECT,
        "Resource",
        DraftOption,
    )

    if available.is_empty():
        push_warning("Out of options in draft pool / all consumed")
        return []
    elif available.size() <= count:
        if available.size() < count:
            push_warning("Not enough options, returning everything %s" % [available])
        return available

    print_debug("[Draft Pool] options: %s" % [available])
    var total_prob: float = 0.0
    var probs: Array[float] = []
    var idx: int = 0
    var available_count: int = available.size()

    if probs.resize(available_count) != OK:
        push_error("Failed to allocate probability array")
        return []

    for opt: DraftOption in available:
        total_prob += opt.draft_probability
        probs[idx] = total_prob
        idx += 1

    var drafts: Array[DraftOption] = []
    for _idx: int in range(count):
        if available_count < 1:
            push_error("No more rooms available %s we should have known this" % [available])
            return drafts

        var p: float = randf_range(0, probs[available_count - 1])
        var opt_idx: int = probs.find_custom(func (v: float) -> bool: return p <= v)

        if opt_idx < 0:
            push_warning("Unexpected option selection - option not found drawing one on unweighted random")
            opt_idx = randi_range(0, available_count - 1)

        drafts.append(available[opt_idx])
        available.remove_at(opt_idx)
        var diff: float = probs[opt_idx] if opt_idx == 0 else probs[opt_idx] - probs[opt_idx - 1]
        probs.remove_at(opt_idx)
        available_count -= 1
        for idx2: int in range(opt_idx, available_count):
            probs[opt_idx] -= diff

    return drafts

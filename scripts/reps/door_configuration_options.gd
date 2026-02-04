extends Node3D
class_name DoorConfigurationOptions

@export var _connected: Array[PrioritizedDoorConfiguration]
@export var _to_wall: Array[PrioritizedDoorConfiguration]
@export var _to_nothing: Array[PrioritizedDoorConfiguration]
@export var _panic: Array[PrioritizedDoorConfiguration]

var finalized: bool
var _current_data: DoorData

func resolve_connected_doors(data: DoorData, other: Room3D) -> void:
    if finalized || data == _current_data:
        return

    _select_and_apply_config(_connected, data, other)

func resolve_door_to_wall(data: DoorData, other: Room3D) -> void:
    if finalized || data == _current_data:
        return

    _select_and_apply_config(_to_wall, data, other)

func resolve_door_to_nothing(data: DoorData) -> void:
    if finalized || data == _current_data:
        return

    _select_and_apply_config(_to_nothing, data, null)

func resolve_panic() -> void:
    if finalized:
        return

    _select_and_apply_config(_panic, null, null)

func _select_and_apply_config(
    opts: Array[PrioritizedDoorConfiguration],
    data: DoorData,
    other: Room3D,
) -> void:
    if opts.is_empty():
        return
    elif opts.size() == 1:
        var applicability: PrioritizedDoorConfiguration.Applicability = opts[0].applicable(data, other)
        if opts[0].invoke(applicability.application_version):
            finalized = applicability.finalizes
        return

    var confs: Dictionary[PrioritizedDoorConfiguration.Applicability, PrioritizedDoorConfiguration]
    var max_prio: int = -1

    for opt: PrioritizedDoorConfiguration in opts:
        var applicability: PrioritizedDoorConfiguration.Applicability = opt.applicable(data, other)
        confs[applicability] = opt
        max_prio = maxi(max_prio, applicability.priority)

    var apps: Array[PrioritizedDoorConfiguration.Applicability] = []
    apps.assign(
        confs.keys().filter(
            func (a: PrioritizedDoorConfiguration.Applicability) -> bool:
                return max_prio < 0 || a.priority == max_prio,
        ),
    )

    if apps.size() == 1:
        if confs[apps[0]].invoke(apps[0].application_version):
            finalized = apps[0].finalizes
        return


    var weights: Array[float] = []
    var total: float = 0
    for app: PrioritizedDoorConfiguration.Applicability in apps:
        weights.append(app.weight)
        total += app.weight

    var idx: int = ArrayUtils.pick_weighted_probability_index(weights, total)
    if idx >= 0:
        if confs[apps[idx]].invoke(apps[idx].application_version):
            finalized = apps[idx].finalizes

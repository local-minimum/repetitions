extends Node3D
class_name DoorConfigurationOptions

enum DoorState { UNDECIDED, LOCKED_DOOR, OPEN_DOOR, NO_DOOR }
enum SpecialState { NONE, ONE, TWO }

@export var _door_open_root: Node3D
@export var _door_locked_root: Node3D
@export var _door_no_door_root: Node3D

@export var _special_one: Node3D
@export var _special_two: Node3D

@export var _panic_on_missing_door_node: bool = true

@export var _to_wall_door: DoorState = DoorState.OPEN_DOOR
@export var _to_wall_special: SpecialState = SpecialState.NONE
@export var _to_wall_special_condition: DraftOption

@export var _panic_state: DoorState = DoorState.OPEN_DOOR
@export var _panic_special: SpecialState = SpecialState.NONE
@export var _panic_from_missing_option_cause_warning: bool = false

@export var _to_nothing_door: DoorState = DoorState.LOCKED_DOOR
@export var _to_nothing_special: SpecialState = SpecialState.NONE
@export var _to_nothing_cause_finalize: bool

@export var _to_door_if_other_locked_door: DoorState = DoorState.UNDECIDED
@export var _to_door_if_other_open_door: DoorState = DoorState.UNDECIDED
@export var _to_door_if_other_no_door: DoorState = DoorState.UNDECIDED
@export var _to_door_default: DoorState = DoorState.OPEN_DOOR
@export var _to_door_probabilities: Dictionary[DoorState, float]
@export var _to_door_special_conditions: Dictionary[DraftOption, SpecialState]

var finalized: bool

func resolve_connected_doors(
    own_room: Room3D,
    other_room: Room3D,
    other_conf: DoorConfigurationOptions,
) -> void:
    if other_conf == null:
        resolve_panic()
        return

    var other_state: DoorState = DoorState.UNDECIDED
    other_state = other_conf._get_random_to_door_state()

    var own_state: DoorState = _resolve_own_to_door_state(other_state)
    if other_state == DoorState.UNDECIDED:
        other_state = other_conf._resolve_own_to_door_state(own_state)

    _implement_doorage(_state_to_door(own_state), true)
    other_conf._implement_doorage(other_conf._state_to_door(other_state ), true)

    # TODO: This can be refined by more precise logic for when a special may be activated
    var own_special: SpecialState = _to_door_special_conditions.get(other_room.blueprint.option, SpecialState.NONE)
    _implement_special(_special_to_node(own_special), true)
    var other_special: SpecialState = other_conf._to_door_special_conditions.get(own_room, SpecialState.NONE)
    other_conf._implement_special(other_conf._special_to_node(other_special), true)

    finalized = true
    other_conf.finalized = true


func _resolve_own_to_door_state(other_state: DoorState) -> DoorState:
    match other_state:
        DoorState.UNDECIDED:
            return _get_random_to_door_state_or_default()

        DoorState.LOCKED_DOOR:
            if _to_door_if_other_locked_door != DoorState.UNDECIDED:
                return _to_door_if_other_locked_door

            return _get_random_to_door_state_or_default()

        DoorState.OPEN_DOOR:
            if _to_door_if_other_open_door != DoorState.UNDECIDED:
                return _to_door_if_other_open_door

            return _get_random_to_door_state_or_default()

        DoorState.NO_DOOR:
            if _to_door_if_other_no_door != DoorState.UNDECIDED:
                return _to_door_if_other_no_door

            return _get_random_to_door_state_or_default()

        _:
            push_warning("Don't know how to handle %s" % [DoorState.find_key(other_state)])
            return _get_random_to_door_state_or_default()

func _get_random_to_door_state_or_default() -> DoorState:
    var own_state: DoorState = _get_random_to_door_state()
    if own_state == DoorState.UNDECIDED:
        return _to_door_default
    return  own_state

func _get_random_to_door_state() -> DoorState:
    match _to_door_probabilities.size():
        0:
            return DoorState.UNDECIDED
        1:
            return _to_door_probabilities.keys()[0]
        _:
            var weigths: Array[float]
            weigths.assign(_to_door_probabilities.values())
            var idx: int = ArrayUtils.pick_weighted_probability_index(weigths)
            if idx >= 0 && idx < weigths.size():
                return _to_door_probabilities.keys()[idx]

            push_warning("%s failed to pick state from %s" % [self, _to_door_probabilities])
            return DoorState.UNDECIDED

func resolve_door_to_wall(other_room: Room3D) -> void:
    var door: Node3D = _state_to_door(_to_wall_door)
    if _panic_on_missing_door_node && door == null:
        resolve_panic(_panic_from_missing_option_cause_warning)
        return

    _implement_doorage(door)

    # TODO: This can be refined by more precise logic for when a special may be activated
    if _to_wall_special_condition == null || other_room != null && other_room.blueprint.option == _to_wall_special_condition:
        _implement_special(_special_to_node(_to_wall_special))
    else:
        _implement_special(null)

    finalized = true

func resolve_door_to_nothing() -> void:
    var door: Node3D = _state_to_door(_to_nothing_door)
    if _panic_on_missing_door_node && door == null:
        resolve_panic(_panic_from_missing_option_cause_warning)
        return

    _implement_doorage(door, _to_nothing_cause_finalize)

    # TODO: This can be refined by more precise logic for when a special may be activated
    _implement_special(_special_to_node(_to_nothing_special), _to_nothing_cause_finalize)

    finalized = true

func resolve_panic(warn: bool = false) -> void:
    var door: Node3D = _state_to_door(_panic_state)
    if door == null:
        for opt: Node3D in [_door_open_root, _door_no_door_root, _door_locked_root]:
            if opt != null:
                door = opt
                if warn:
                    push_warning("Panic didn't have a default fallback door config for %s, opting for %s" % [self, opt])
                break

    if door == null && warn:
        push_warning("There's no valid panic door option for %s" % [self])

    _implement_doorage(door)
    _implement_special(_special_to_node(_panic_special))
    finalized = true

func _state_to_door(state: DoorState) -> Node3D:
    match state:
        DoorState.LOCKED_DOOR:
            return _door_locked_root
        DoorState.OPEN_DOOR:
            return _door_open_root
        DoorState.NO_DOOR:
            return _door_no_door_root
        DoorState.UNDECIDED:
            return null
        _:
            push_warning("State %s not handled" % [DoorState.find_key(state)])
            return null

func _special_to_node(special: SpecialState) -> Node3D:
    match special:
        SpecialState.NONE:
            return null
        SpecialState.ONE:
            return _special_one
        SpecialState.TWO:
            return _special_two
        _:
            push_warning("Special %s not handled" % [SpecialState.find_key(special)])
            return null

func _implement_doorage(option: Node3D, finalize: bool = true) -> void:
    if _door_locked_root != null && option != _door_locked_root:
        if finalize:
            _door_locked_root.queue_free()
            _door_locked_root = null
        elif _door_locked_root.is_inside_tree():
            var p: Node = _door_locked_root.get_parent()
            if p != null:
                p.remove_child(_door_locked_root)

    if _door_open_root != null && option != _door_open_root:
        if finalize:
            _door_open_root.queue_free()
            _door_open_root = null
        elif _door_open_root.is_inside_tree():
            var p: Node = _door_open_root.get_parent()
            if p != null:
                p.remove_child(_door_locked_root)

    if _door_no_door_root != null && option != _door_no_door_root:
        if finalize:
            _door_no_door_root.queue_free()
            _door_no_door_root = null
        elif _door_no_door_root.is_inside_tree():
            var p: Node = _door_no_door_root.get_parent()
            if p != null:
                p.remove_child(_door_no_door_root)

    if option != null && !option.is_inside_tree():
        add_child(option)

func _implement_special(option: Node3D, finalize: bool = true) -> void:
    if _special_one != null && _special_one != option:
        if finalize:
            _special_one.queue_free()
            _special_one = null
        elif _special_one.is_inside_tree():
            var p: Node = _special_one.get_parent()
            if p != null:
                p.remove_child(_special_one)

    if _special_two != null && _special_two != option:
        if finalize:
            _special_two.queue_free()
            _special_two = null
        elif _special_two.is_inside_tree():
            var p: Node = _special_two.get_parent()
            if p != null:
                p.remove_child(_special_two)

    if option != null && !option.is_inside_tree():
        add_child(option)

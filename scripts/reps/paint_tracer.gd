extends MeshInstance3D
class_name PaintTracer

const _POINT_META: String = "POINT"
const _LINE_META: String = "LINE"

signal painting_updated(matches_solution: bool)
signal valid_line_connections(points: Array[int])

## Should have int meta "POINT" with values 0,1,2,4,7,12,20,33 (larger than that doesn't fit in a 64 bit int)
@export var _points: Array[Area3D]
## Should have int meta "LINE" with values set to the sum of the two points the line connects
@export var _lines: Array[Node3D]


func _enter_tree() -> void:
    var optimal_pt_ids: Array[int] = [0, 1, 2, 4, 7, 12, 20, 33]

    for pt: Area3D in _points:
        var pt_id: int = pt.get_meta(_POINT_META, -1)
        if pt_id < 0:
            push_error("Point %s doesn't have a valid int meta %s set. Must be zero or positive" % [pt, _POINT_META])
            continue
        elif !optimal_pt_ids.has(pt_id):
            push_warning("Point %s doesn't have an optimal id (%s) set on its %s meta, choose from %s" % [
                pt, pt_id, _POINT_META, optimal_pt_ids,
            ])

        if pt.input_event.connect(_handle_point_input.bind(pt_id)) != OK:
            push_error("Failed to connect %s input event" % [pt])

    _all_lines = 0
    for line: Node3D in _lines:
        var line_id: int = line.get_meta(_LINE_META, -1)
        if line_id > 0:
            _all_lines += 1 << (line_id - 1)

var _all_lines: int

func set_solution(point_sequence: Array[int]) -> void:
    _solution_hash = 0
    var last_pt: int = -1
    for pt: int in point_sequence:
        if last_pt >= 0:
            var line_hash: int = _line_hash(last_pt, pt)
            if (_all_lines & line_hash) == line_hash:
                _solution_hash |= _line_hash(last_pt, pt)
            else:
                push_error("There's no line between %s and %s - ignoring" % [last_pt, pt])
        last_pt = pt


func _line_hash(from_pt: int, to_pt: int) -> int:
    if from_pt < 0 || to_pt < 0:
        push_error("At least one of the points [%s - %s] is not valid (<0)" % [from_pt, to_pt])
        return 0
    elif from_pt == to_pt:
        push_error("A valid line must be between two different points, but both have id %s" % [from_pt])
        return 0

    return 1 << (from_pt + to_pt - 1)

func _handle_point_input(
    _cam: Node,
    evt: InputEvent,
    _evt_pos: Vector3,
    _evt_norm: Vector3,
    _shape_idx: int,
    point_id: int,
) -> void:
    #print_debug("%s %s" % [point_id, evt])
    if evt.is_echo():
        return

    if evt is InputEventMouseButton:
        var button_evt: InputEventMouseButton = evt
        if !_drawing && button_evt.is_pressed() && button_evt.button_index == MOUSE_BUTTON_LEFT:
            _clear_drawing()
            _active_point = point_id
            _drawing = true
        elif _drawing && button_evt.is_released() && button_evt.button_index == MOUSE_BUTTON_LEFT:
            _drawing = false
            painting_updated.emit(_solution_hash == _drawing_hash)

    elif _drawing && evt is InputEventMouseMotion && _drawing:
        if point_id != _active_point:
            var line_hash: int = _line_hash(_active_point, point_id)
            #print_debug("%s %s" % [_drawing_hash, line_id])
            if _line_hash_valid_and_not_in_drawing(line_hash):
                var line_id: int = _active_point + point_id
                for line: Node3D in _lines:
                    #print_debug("%s is %s, looking for %s + %s" % [line, line.get_meta(_LINE_META, -1), _active_point, point_id])
                    if line.get_meta(_LINE_META, -1) == line_id:
                        line.show()
                        break
                _active_point = point_id
                _drawing_hash |= line_hash
                _emit_valid_point_connections()

func _line_hash_valid_and_not_in_drawing(line_hash: int) -> bool:
    return (_all_lines & line_hash) == line_hash && (_drawing_hash & line_hash) == 0

func _emit_valid_point_connections() -> void:
    var valid: Array[int]
    for pt: Node3D in _points:
        var pt_id: int = pt.get_meta(_POINT_META, -1)
        if pt_id < 0 || pt_id == _active_point:
            continue

        var line_hash: int = _line_hash(_active_point, pt_id)
        if _line_hash_valid_and_not_in_drawing(line_hash):
            valid.append(pt)

    valid_line_connections.emit(valid)

var _drawing: bool = false
var _active_point: int
var _drawing_hash: int
var _solution_hash: int

func _clear_drawing() -> void:
    _drawing_hash = 0
    for line: Node3D in _lines:
        line.hide()

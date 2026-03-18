extends MeshInstance3D
class_name PaintTracer

const _POINT_META: String = "POINT"
const _LINE_META: String = "LINE"

@export var _points: Array[Area3D]
@export var _lines: Array[Node3D]

func _enter_tree() -> void:
    for pt: Area3D in _points:
        if pt.input_event.connect(_handle_point_input.bind(pt.get_meta(_POINT_META, 0))) != OK:
            push_error("Failed to connect %s input event" % [pt])

    _all_lines = 0
    for line: Node3D in _lines:
        var line_id: int = line.get_meta(_LINE_META, -1)
        if line_id > 0:
            _all_lines += 1 << (line_id - 1)

var _all_lines: int

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

    elif _drawing && evt is InputEventMouseMotion && _drawing:
        if point_id != _active_point:
            var line_id: int = 1 << (_active_point + point_id - 1)
            #print_debug("%s %s" % [_drawing_hash, line_id])
            if (_all_lines & line_id) == line_id:
                if (_drawing_hash & line_id) == 0:
                    for line: Node3D in _lines:
                        print_debug("%s is %s, looking for %s + %s" % [line, line.get_meta(_LINE_META, -1), _active_point, point_id])
                        if line.get_meta(_LINE_META, -1) == _active_point + point_id:
                            line.show()
                            break
                    _active_point = point_id
                    _drawing_hash |= line_id

var _drawing: bool = false
var _active_point: int
var _drawing_hash: int

func _clear_drawing() -> void:
    _drawing_hash = 0
    for line: Node3D in _lines:
        line.hide()

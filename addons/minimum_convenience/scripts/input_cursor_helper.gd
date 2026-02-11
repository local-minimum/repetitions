class_name InputCursorHelper

enum State { HOVER, DRAG, FORBIDDEN }

static var _forbidden: Array[Node]
static var _hovered: Array[Node]
static var _dragged: Array[Node]

static func reset() -> void:
    for node: Node in _hovered:
        if is_instance_valid(node):
            remove_node(node)
    for node: Node in _dragged:
        if is_instance_valid(node):
            remove_node(node)
    for node: Node in _forbidden:
        if is_instance_valid(node):
            remove_node(node)

static func add_state(node: Node, state: State) -> void:
    match state:
        State.HOVER:
            if !_hovered.has(node):
                _hovered.append(node)
        State.DRAG:
            if !_dragged.has(node):
                _dragged.append(node)
        State.FORBIDDEN:
            if !_forbidden.has(node):
                _forbidden.append(node)

    _sync_cursor(node)

## Removes all states for node
static func remove_node(node: Node) -> void:
    _hovered.erase(node)
    _dragged.erase(node)
    _forbidden.erase(node)
    _sync_cursor(node)

static func remove_state(node: Node, state: State) -> void:
    match state:
        State.HOVER:
            _hovered.erase(node)
        State.DRAG:
            _dragged.erase(node)
        State.FORBIDDEN:
            _forbidden.erase(node)

    _sync_cursor(node)


static func _sync_cursor(node: Node) -> void:
    if !_forbidden.is_empty():
        # print_debug("[Input Cursor Helper] -> Forbidden")
        _sync_node_cursor(node, Control.CURSOR_FORBIDDEN)
        Input.set_default_cursor_shape(Input.CURSOR_FORBIDDEN)
        __SignalBus.on_captured_cursor_change.emit(Input.CURSOR_FORBIDDEN)
    elif !_dragged.is_empty():
        # print_debug("[Input Cursor Helper] -> Drag")
        _sync_node_cursor(node, Control.CURSOR_DRAG)
        Input.set_default_cursor_shape(Input.CURSOR_DRAG)
        __SignalBus.on_captured_cursor_change.emit(Input.CURSOR_DRAG)
    elif !_hovered.is_empty():
        # print_debug("[Input Cursor Helper] -> Hover")
        _sync_node_cursor(node, Control.CURSOR_POINTING_HAND)
        Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
        __SignalBus.on_captured_cursor_change.emit(Input.CURSOR_POINTING_HAND)
    else:
        # print_debug("[Input Cursor Helper] -> Default")
        _sync_node_cursor(node, Control.CURSOR_ARROW)
        Input.set_default_cursor_shape(Input.CURSOR_ARROW)
        __SignalBus.on_captured_cursor_change.emit(Input.CURSOR_ARROW)

static func _sync_node_cursor(node: Node, shape: Control.CursorShape) -> void:
    if node is Control:
        var control: Control = node
        control.mouse_default_cursor_shape = shape

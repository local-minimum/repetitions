extends Node

@export var _crossroads_west_wall: Node3D
@export var _crossroads_east_wall: Node3D
@export var _crossroads_south_wall: Node3D
@export var _crossroads_north_wall: Node3D

@export var _gate_wall: Node3D
@export var _gate_name: String = "Bars*"

@export var _forbidden_look_threshold: float = 0.5

var gate: Node3D:
    get():
        if gate == null && _gate_wall != null:
            gate = _gate_wall.find_child(_gate_name)
        return gate
            
enum State { DEFAULT, ENTERED_LEFT, INSIDE_LEFT, ENTERED_RIGHT, INSIDE_RIGHT, READY, APPROACTING, SOLVED }

var state_history: Array[State] = []
var state: State:
    get():
        if state_history.is_empty():
            return State.DEFAULT
        return state_history[-1]
    set(value):
        if value == state:
            return

        if state_history.size() > 3:
            state_history.remove_at(0)
        state_history.append(value)
        _sync()
        # print_debug("Updating state history to %s" % [state_history.map(func (s: State) -> String: return State.find_key(s))])
        # print_stack()
        
func _ready() -> void:
    # print_debug("State is %s" % State.find_key(state))
    _sync()
    
func _sync() -> void:
    _sync_gate()
    _sync_crossroads()

func _sync_crossroads() -> void:
    match state:
        State.INSIDE_LEFT, State.INSIDE_RIGHT:
            toggle_piece(_crossroads_east_wall, false)
            toggle_piece(_crossroads_west_wall, false)
            toggle_piece(_crossroads_north_wall, true)
            toggle_piece(_crossroads_south_wall, true)
        State.DEFAULT, State.SOLVED, State.READY:
            toggle_piece(_crossroads_east_wall, true)
            toggle_piece(_crossroads_west_wall, true)
            toggle_piece(_crossroads_south_wall, false)
            toggle_piece(_crossroads_north_wall, false)
            
func _sync_gate() -> void:
    match state:
        State.READY, State.SOLVED:
            toggle_piece(gate, false)
        _:
            toggle_piece(gate, true)


func _on_area_out_left_body_entered(body: Node3D) -> void:
    if state == State.SOLVED || PhysicsGridPlayerController.find_player_in_tree(body) == null:
        return
         
    if state == State.INSIDE_RIGHT:
        state = State.READY
    else:    
        state = State.ENTERED_LEFT
    

func _on_area_left_in_body_entered(body: Node3D) -> void:
    if state == State.SOLVED || PhysicsGridPlayerController.find_player_in_tree(body) == null:
        return
            
    if state == State.INSIDE_RIGHT:
        return
    
    state = State.INSIDE_LEFT


func _on_area_cross_roads_body_entered(body: Node3D) -> void:
    if state == State.SOLVED:
        return
        
    if state != State.READY:
        return
    
    var player: PhysicsGridPlayerController = PhysicsGridPlayerController.find_player_in_tree(body)
    if player == null:
        return
        
    var player_forward: Vector3 = -player.global_basis.z
    player_forward.y = 0
    player_forward = player_forward.normalized()
    
    var forbidden_direction: Vector3 = (gate.global_position - player.global_position)
    forbidden_direction.y = 0
    forbidden_direction = forbidden_direction.normalized()

    if player_forward.dot(forbidden_direction) > _forbidden_look_threshold:
        state = State.DEFAULT

func _on_area_in_right_body_entered(body: Node3D) -> void:
    if state == State.SOLVED || PhysicsGridPlayerController.find_player_in_tree(body) == null:
        return
           
    if state == State.INSIDE_LEFT:
        return
        
    state = State.INSIDE_RIGHT
    
func _on_area_out_mid_body_entered(_body: Node3D) -> void:
    pass # Replace with function body.

func _on_area_out_right_body_entered(body: Node3D) -> void:
    if state == State.SOLVED || PhysicsGridPlayerController.find_player_in_tree(body) == null:
        return
        
    if state == State.INSIDE_LEFT:
        state = State.READY
    else:
        state = State.ENTERED_RIGHT

func _on_area_goal_body_entered(body: Node3D) -> void:
    if PhysicsGridPlayerController.find_player_in_tree(body) == null:
        return
    state = State.SOLVED

func toggle_piece(n: Node3D, active: bool) -> void:
    if active:
        n.show()
        NodeUtils.enable_physics_in_children(n)
    else:
        n.hide()
        NodeUtils.disable_physics_in_children(n)

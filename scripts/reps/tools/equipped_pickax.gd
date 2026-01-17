extends EquippedTool

@export var _anim: AnimationPlayer
@export var _anim_name: String = "Wack"
@export var _caster: ShapeCast3D
@export var _player: PhysicsGridPlayerController:
    get():
        if _player == null:
            _player = NodeUtils.find_parent_type(self, "PhysicsGridPlayerController")
        return _player
        
var _busy: bool

func _input(event: InputEvent) -> void:
    if !enabled || event.is_echo():
        return
        
    if event.is_action_pressed("crawl_search"):
        get_viewport().set_input_as_handled()
        
        _ax()

func _ax() -> void:
    if _busy:
        return

    if _anim != null && !_anim_name.is_empty():
        _player.cinematic = true
        _anim.play(_anim_name)
         
        _busy = true
        
        if _anim.animation_finished.connect(_ready_next_ax, CONNECT_ONE_SHOT) != OK:
            push_error("Failed to connect animation finished")
            _ready_next_ax(_anim_name)
     
func _ready_next_ax(anim_name: String) -> void:
    if _anim_name == anim_name:
        _busy = false
        _player.cinematic = false
        
        if _caster.is_colliding():
            var col: Object = _caster.get_collider(0)
            if col is Node3D:
                var dir: CardinalDirections.CardinalDirection = CardinalDirections.node_planar_rotation_to_direction(_player)
                __SignalBus.on_use_pickax.emit(col, dir)
                

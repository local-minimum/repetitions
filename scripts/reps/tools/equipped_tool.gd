extends Node3D
class_name EquippedTool

@export var _player: PhysicsGridPlayerController:
    get():
        if _player == null:
            _player = NodeUtils.find_parent_type(self, "PhysicsGridPlayerController")
        return _player

@export var _anim: AnimationPlayer
@export var _anim_name: String
@export var _caster: ShapeCast3D
@export var _usable: bool = true

var _busy: bool

var enabled: bool:
    set(value):
        if value:
            show()
            if _usable:
                set_process_unhandled_input(true)

        else:
            hide()
            set_process_unhandled_input(false)

        enabled = value

func _ready() -> void:
    enabled = false

# We process tool usage/pickax in unhandled to let other things take prio
func _unhandled_input(event: InputEvent) -> void:
    if !enabled || event.is_echo():
        return

    if event.is_action_pressed(&"crawl_search"):
        get_viewport().set_input_as_handled()
        print_debug("Consuming 'search' to %s" % [self])
        _use()

func _use() -> void:
    if _busy:
        return

    if _anim != null && !_anim_name.is_empty():
        _player.add_cinematic_blocker(self)
        _anim.play(_anim_name)

        _busy = true

        if _anim.animation_finished.connect(_complete_use, CONNECT_ONE_SHOT) != OK:
            push_error("Failed to connect animation finished")
            _complete_use(_anim_name)

func _complete_use(anim_name: String) -> void:
    if _anim_name == anim_name:
        _busy = false
        _player.remove_cinematic_blocker(self)

        if _caster != null && _caster.is_colliding():
            var col: Object = _caster.get_collider(0)
            if col is Node3D:
                execute_action(col as Node3D, _caster)
            else:
                print_debug("Collided with %s, which is not a node3d" % [col])
        else:
            print_debug("Caster %s hits nothing" % [_caster])

func execute_action(target: Node3D, caster: ShapeCast3D) -> void:
    push_warning("%s does not have an execute action relating to hitting %s with %s" % [self, target, caster])

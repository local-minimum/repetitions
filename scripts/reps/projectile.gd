extends Node3D
class_name Projectile

@export var _area: Area3D
@export var velocity: float = 1.0

signal on_hit(body: Node3D, projectile: Projectile)
signal on_miss(projetile: Projectile)

var origin: Vector3
var target: Vector3

var _flying: bool

func _enter_tree() -> void:
    if _area.body_entered.connect(_handle_body_entered) != OK:
        push_error("Failed to connect body entered")

    set_process(false)

func _handle_body_entered(body: Node3D) -> void:
    _flying = false
    on_hit.emit(body, self)
    _collide()

@warning_ignore_start("shadowed_variable")
func launch(origin: Vector3, target: Vector3, lifetime: float = -1) -> void:
    @warning_ignore_restore("shadowed_variable")

    if _flying:
        push_error("Cannot relaunch projectiles that are already flying")
        return

    self.origin = origin
    self.target = target

    global_position = origin
    global_rotation = Basis.looking_at(target - origin).get_euler()

    _flying = true

    set_process(true)

    if lifetime > 0:
        _expire_after(lifetime)

func _expire_after(lifetime: float) -> void:
    await get_tree().create_timer(lifetime).timeout
    _flying = false
    on_miss.emit(self)
    _expire()

func _process(delta: float) -> void:
    if !_flying:
        return

    global_position += -global_basis.z * delta * velocity

func _expire() -> void:
    queue_free()

func _collide() -> void:
    queue_free()

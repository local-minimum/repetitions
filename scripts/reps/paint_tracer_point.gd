extends InteractionBody3D
class_name PaintTracerPoint

@export var tracer: PaintTracer
@export var point: Node3D
@export var particles: GPUParticles3D

func _enter_tree() -> void:
    super._enter_tree()

    if tracer.valid_line_connections.connect(_handle_valid_line_connections) != OK:
        push_error("Failed to connect valid line connections")

    if tracer.painting_updated.connect(_handle_painting_completed) != OK:
        push_error("Failed to connect painting updated")

    show_particles = false

var show_particles: bool:
    set(value):
        show_particles = value
        if value:
            particles.show()
            particles.emitting = true
        else:
            particles.hide()
            particles.emitting = false

var point_id: int:
    get():
        if point == null:
            return -1
        return point.get_meta(PaintTracer.POINT_META, -1)

func _handle_valid_line_connections(points: Array[int]) -> void:
    show_particles = points.has(point_id)

func _handle_painting_completed(_matches_solution: bool) -> void:
    show_particles = true

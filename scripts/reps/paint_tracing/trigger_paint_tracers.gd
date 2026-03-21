extends Area3D

@export var tracers: Array[PaintTracer]

func _on_body_entered(body: Node3D) -> void:
    if (
        PhysicsGridPlayerController.find_in_tree(body) !=
        PhysicsGridPlayerController.last_connected_player
    ):
        return

    for tracer: PaintTracer in tracers:
        tracer.set_point_hints(true)


func _on_body_exited(body: Node3D) -> void:
    if (
        PhysicsGridPlayerController.find_in_tree(body) !=
        PhysicsGridPlayerController.last_connected_player
    ):
        return

    for tracer: PaintTracer in tracers:
        tracer.set_point_hints(false)

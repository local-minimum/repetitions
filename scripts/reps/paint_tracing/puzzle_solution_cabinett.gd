extends Node3D

@export var animator: AnimationPlayer
@export var open_anim: String
@export var slots: Array[Node3D]
@export var tracer_frame: LineTracersFrame
@export var solutions: Array[PaintingSolution]

func _enter_tree() -> void:
    _seed_solution()

    if tracer_frame.succeed.connect(_open_door) != OK:
        push_error("Failed to connect tracter frame succeed")

func _seed_solution() -> void:
    solutions.shuffle()

    for idx: int in slots.size():
        var painting_solution: PaintingSolution = solutions[idx]
        slots[idx].add_child(painting_solution.spawn_scene())
        tracer_frame.set_tracer_solution(idx, painting_solution.point_sequence)

func _open_door() -> void:
    animator.play(open_anim)

extends Node3D

@export var tracers: Array[PaintTracer]
@export var button: InteractionBody3D
@export var button_animator: AnimationPlayer
@export var button_animation: String

signal fail
signal succeed

enum TracerStatus { UNSET, CORRECT, WRONG }

var _statuses: Dictionary[PaintTracer ,TracerStatus]
var _animating_button: bool

func _enter_tree() -> void:
    button.interactable = false

    for tracer: PaintTracer in tracers:
        _statuses[tracer] = TracerStatus.UNSET
        if tracer.painting_updated.connect(_handle_painting_updated.bind(tracer)) != OK:
            push_error("Failed to connect painting updated")

func _handle_painting_updated(matches_solution: bool, tracer: PaintTracer) -> void:
    _statuses[tracer] = TracerStatus.CORRECT if matches_solution else TracerStatus.WRONG
    print_debug("Current statuses are %s" % [_statuses])

    if !_statuses.values().has(TracerStatus.UNSET):
        # TODO: Do fancy
        print_debug("Enable interactable pressing")
        button.interactable = true

func set_tracer_solution(ordinal: int, point_sequence: Array[int]) -> void:
    tracers[ordinal].set_solution(point_sequence)

func _on_click_button() -> void:
    print_debug("Button pressed")

    if _animating_button || _statuses.values().has(TracerStatus.UNSET):
        print_debug("Press was refused because animating %s or statuses %s" % [_animating_button, _statuses])
        return

    _animating_button = true
    for tracer: PaintTracer in tracers:
        tracer.set_interactiable(false)

    button_animator.play(button_animation)

    await get_tree().create_timer(0.5).timeout
    if _statuses.values().has(TracerStatus.WRONG):
        print_debug("Solution was wrong: %s" % [_statuses])
        for tracer: PaintTracer in tracers:
            tracer.clear()
            tracer.set_interactiable(true)
            _statuses[tracer] = TracerStatus.UNSET
        fail.emit()

    else:
        print_debug("Solution was correct")
        succeed.emit()

    await get_tree().create_timer(1.0).timeout
    _animating_button = false
    button.interactable = false

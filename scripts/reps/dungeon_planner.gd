extends Node2D

@export var grid: Grid2D
@export var rooms: Array[BlueprintRoom]

func _ready() -> void:
    for room: BlueprintRoom in rooms:
        room.grid = grid
        room.snap_to_grid()

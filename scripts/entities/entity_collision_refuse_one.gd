extends EntityCollisionResolutionSystem

enum Priority { FIRST, PROGRESS, FIRST_TO_ARRIVE, PLAYER_THEN_FIRST }

@export var _priority: Priority = Priority.FIRST

func _resolve_collision(a: GridEntity, b: GridEntity) -> void:
    match _priority:
        Priority.FIRST:
            if a.translation_start_msec < b.translation_start_msec:
                b.force_abort_translation.emit()
            else:
                a.force_abort_translation.emit()

        Priority.PROGRESS:
            if a.translation_progress > b.translation_progress:
                b.force_abort_translation.emit()
            else:
                a.force_abort_translation.emit()

        Priority.FIRST_TO_ARRIVE:
            if a.translation_end_msec < b.translation_end_msec:
                b.force_abort_translation.emit()
            else:
                a.force_abort_translation.emit()

        Priority.PLAYER_THEN_FIRST:
            if a.player != null && b.player == null:
                b.force_abort_translation.emit()
            if b.player != null:
                a.force_abort_translation.emit()
            elif a.translation_start_msec < b.translation_start_msec:
                b.force_abort_translation.emit()
            else:
                a.force_abort_translation.emit()

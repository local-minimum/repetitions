@tool

extends TrackFollow
class_name TrackEngine

@export var speed: float = 0.25
@export var _interaction_body: InteractionBody3D

@export var downstream_carriage: TrackCarriage

var _running: bool = false
var running: bool:
    get():
        return _running

func _enter_tree() -> void:
    if _interaction_body.execute_interaction.connect(_handle_interaction) != OK:
        push_error("Failed to connect interaction")

func _handle_interaction() -> void:
    _running = !_running

    if (
        _position != null &&
        _position.at_edge &&
        current_track != null &&
        current_track.get_connection_mode(_position) == Track.ConnectionMode.TRACK &&
        current_track.get_next_track(_position.at_start) == null
    ):
        travel_in_reverse = !travel_in_reverse
        travel_forward = !travel_forward

    __SignalBus.on_train_interaction.emit(self)

func _process(delta: float) -> void:
    if !_running || Engine.is_editor_hint():
        return

    if current_track == null:
        return

    if _position == null:
        snap_to_track(true)
        return

    #var prev: float = _position.offset_distance
    var off: float = _position.offset_distance + (delta * (1.0 if travel_forward else -1.0) * speed)
    _position = current_track.get_offset_position_global(off, true)
    #print_debug("%s: %s -> %s == %s" % [prev, delta, _position.offset_distance, off])

    if _position.at_edge:
        match current_track.get_connection_mode(_position):
            Track.ConnectionMode.TRACK:
                var next_track: Track = current_track.get_next_track(_position.at_start)
                if next_track != null:
                    if next_track != current_track && current_track.is_mirrored_connection_direction(next_track, _position.at_start):
                        travel_forward = !travel_forward
                    off = current_track.get_offset_overshoot(_position.offset_distance)
                    if !travel_forward:
                        off = next_track.get_offset_from_end(off)

                    current_track = next_track
                    _position = current_track.get_offset_position_global(off, true)
                else:
                    # We should have had a track continuing here but there's nothing yet
                    _running = false
            Track.ConnectionMode.STOP:
                # We hit an end of track, lets reverse direction and stop
                stop_engine()
            Track.ConnectionMode.NONE:
                # We left the track, don't know what more to do
                stop_engine()

    _sync_position(true)

    if downstream_carriage != null:
        var next_track_off_distance: float = global_distance_to_downstream_connector + downstream_carriage.global_distance_to_upstream_connector
        if travel_forward != travel_in_reverse:
            next_track_off_distance *= -1

        print_debug("Asking %s to place itself at off %s (delta %s)" % [downstream_carriage, off + next_track_off_distance, next_track_off_distance])

        downstream_carriage.calculate_position_and_rotation(
            current_track,
            off + next_track_off_distance
        )

func stop_engine() -> void:
    _running = false
    travel_in_reverse = !travel_in_reverse
    travel_forward = !travel_forward

static func find_in_parent(node: Node) -> TrackEngine:
    if node == null:
        return null

    if node is TrackEngine:
        return node

    return find_in_parent(node.get_parent())

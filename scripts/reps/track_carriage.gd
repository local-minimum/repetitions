@tool
extends TrackFollow
class_name TrackCarriage

@export var upstream_follow: TrackFollow
@export var downstream_carriage: TrackCarriage

var _engine: TrackEngine:
    get():
        if upstream_follow is TrackEngine:
            return upstream_follow
        if upstream_follow is TrackCarriage:
            return (upstream_follow as TrackCarriage)._engine
        return null

func calculate_position_and_rotation(track: Track, off: float) -> void:
    _position = track.get_offset_position_global(off, true)
    #print_debug("%s: %s -> %s == %s" % [prev, delta, _position.offset_distance, off])
    var sync_position: bool = true

    if _position.at_edge:
        match track.get_connection_mode(_position):
            Track.ConnectionMode.TRACK:
                var next_track: Track = track.get_next_track(_position.at_start)
                if next_track != null:
                    if next_track != current_track && current_track.is_mirrored_connection_direction(next_track, _position.at_start):
                        moving_in_track_forwards_direction = !moving_in_track_forwards_direction
                    off = track.get_offset_overshoot(_position.offset_distance)
                    if !moving_in_track_forwards_direction:
                        off = next_track.get_offset_from_end(off)

                    track = next_track
                    _position = track.get_offset_position_global(off, true)
                else:
                    # TODO: Ease towards upstreams rotation and position
                    pass
            Track.ConnectionMode.STOP:
                var e: TrackEngine = _engine
                e.stop_engine()

            Track.ConnectionMode.NONE:
                # We left the track, lets just keep moving backwards then
                track = null
                if upstream_follow != null:
                    var d_engine_connector: Vector3 = upstream_follow.downstream_connector.global_position - global_position
                    var d_connector: Vector3 = upstream_connector.global_position - global_position
                    var a: float = d_connector.signed_angle_to(d_engine_connector, global_basis.y)
                    global_basis = global_basis.rotated(global_basis.y, a * 0.1)

                    d_engine_connector = upstream_follow.downstream_connector.global_position - global_position
                    d_connector = upstream_connector.global_position - global_position
                    a = d_connector.signed_angle_to(d_engine_connector, global_basis.x)
                    global_basis = global_basis.rotated(global_basis.x, a * 0.1)

                    var transl: Vector3 = upstream_follow.downstream_connector.global_position - upstream_connector.global_position
                    #print_debug("To align our connectors %s needs to move %s" % [self, transl])
                    global_position += transl
                    sync_position = false

    current_track = track
    if sync_position:
        _sync_position(true)

        # This fucks everything up when switching tracks
        # var d_engine_connector: Vector3 = upstream_follow.downstream_connector.global_position - global_position
        # var d_connector: Vector3 = upstream_connector.global_position - global_position
        # var a: float = d_connector.signed_angle_to(d_engine_connector, global_basis.y)
        # print_debug("%s needs rotate %s" % [self, a])
        # global_basis = global_basis.rotated(global_basis.y, a * 0.1)

        # d_engine_connector = upstream_follow.downstream_connector.global_position - global_position
        # d_connector= upstream_connector.global_position - global_position
        # a = d_connector.signed_angle_to(d_engine_connector, global_basis.x)
        # print_debug("%s needs rotate %s" % [self, a])
        # global_basis = global_basis.rotated(global_basis.x, a * 0.25)


    if downstream_carriage != null:
        var next_track_off_distance: float = global_distance_to_downstream_connector + downstream_carriage.global_distance_to_upstream_connector
        if moving_in_track_forwards_direction != reversing:
            next_track_off_distance *= -1
        print_debug("Asking %s to place itself at off %s (delta %s)" % [downstream_carriage, off + next_track_off_distance, next_track_off_distance])
        downstream_carriage.calculate_position_and_rotation(
            track,
            off + next_track_off_distance
        )

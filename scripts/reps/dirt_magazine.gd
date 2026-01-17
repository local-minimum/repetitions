extends Node
class_name DirtMagazine

@export_file var _block_solid_path: String
@export_file var _block_dug_one_path: String
@export_file var _block_dug_two_straight_path: String
@export_file var _block_dug_two_bend_path: String
@export_file var _block_dug_three_path: String
@export_file var _block_dug_four_path: String

var _block_solid: PackedScene:
    get():
        if _block_solid == null:
            _block_solid = load(_block_solid_path)
        return _block_solid

var _block_dug_one: PackedScene:
    get():
        if _block_dug_one == null:
            _block_dug_one = load(_block_dug_one_path)
        return _block_dug_one

var _block_dug_two_straight: PackedScene:
    get():
        if _block_dug_two_straight == null:
            _block_dug_two_straight = load(_block_dug_two_straight_path)
        return _block_dug_two_straight

var _block_dug_two_bend: PackedScene:
    get():
        if _block_dug_two_bend == null:
            _block_dug_two_bend = load(_block_dug_two_bend_path)
        return _block_dug_two_bend

var _block_dug_three: PackedScene:
    get():
        if _block_dug_three == null:
            _block_dug_three = load(_block_dug_three_path)
        return _block_dug_three

var _block_dug_four: PackedScene:
    get():
        if _block_dug_four == null:
            _block_dug_four = load(_block_dug_four_path)
        return _block_dug_four

## Place a block as a child to `parent` using the `pos` as local position, ofset as needed by enforced rotations 
func place_block_at(parent: Node3D, pos: Vector3, grid_size: Vector3, digs: Array[CardinalDirections.CardinalDirection] = []) -> Node3D:
    match digs.size():
        0:
            var n: Node3D = _block_solid.instantiate()
            parent.add_child(n)
            n.position = pos
            return n
            
        1:
            var dig: CardinalDirections.CardinalDirection = digs[0]
            var n: Node3D = _block_dug_one.instantiate()
            parent.add_child(n)
            match dig:
                CardinalDirections.CardinalDirection.SOUTH:
                    n.position = pos
                CardinalDirections.CardinalDirection.WEST:
                    n.rotation.y = -PI * 0.5
                    n.position = pos + Vector3.FORWARD * grid_size
                CardinalDirections.CardinalDirection.EAST:
                    n.rotation.y = PI * 0.5
                    n.position = pos + Vector3.RIGHT * grid_size
                CardinalDirections.CardinalDirection.NORTH:
                    n.rotation.y = PI
                    n.position = pos + (Vector3.RIGHT + Vector3.FORWARD) * grid_size
                _:
                    push_error("%s cannot rotate %s to %s, only planar cardinals allowed, using default rotation" % [
                        name, _block_dug_one.resource_path, CardinalDirections.name(dig),
                    ])
                    n.position = pos
            return n
        
        2:
            if CardinalDirections.invert(digs[0]) == digs[1]:
                var n: Node3D = _block_dug_two_straight.instantiate()
                parent.add_child(n)
                if CardinalDirections.is_parallell(CardinalDirections.CardinalDirection.NORTH, digs[0]):
                    n.position = pos
                elif CardinalDirections.is_parallell(CardinalDirections.CardinalDirection.EAST, digs[0]):
                    n.rotation.y = PI * 0.5
                    n.position = pos + Vector3.RIGHT * grid_size
                else:
                    push_error("%s cannot rotate %s to %s-%s, only straight planar cardinals allowed, using default rotation" % [
                        name, _block_dug_two_straight.resource_path, CardinalDirections.name(digs[0]), CardinalDirections.name(digs[1])
                    ])
                    n.position = pos
                return n
            elif CardinalDirections.ALL_PLANAR_DIRECTIONS.has(digs[0]) && CardinalDirections.ALL_PLANAR_DIRECTIONS.has(digs[1]):
                var n: Node3D = _block_dug_two_bend.instantiate()
                parent.add_child(n)
                
                if digs.has(CardinalDirections.CardinalDirection.SOUTH):
                    if digs.has(CardinalDirections.CardinalDirection.WEST):
                        n.position = pos
                    elif digs.has(CardinalDirections.CardinalDirection.EAST):
                        n.rotation.y = PI * 0.5
                        n.position = pos + Vector3.RIGHT * grid_size
                    else:
                        push_error("%s cannot rotate %s to %s-%s, only orthogonal planar cardinals allowed, using default rotation" % [
                            name, _block_dug_two_bend.resource_path, CardinalDirections.name(digs[0]), CardinalDirections.name(digs[1])
                        ])
                        n.position = pos
                elif digs.has(CardinalDirections.CardinalDirection.WEST) && digs.has(CardinalDirections.CardinalDirection.NORTH):
                    n.rotation.y = -PI * 0.5
                    n.position = pos + Vector3.FORWARD * grid_size
                elif digs.has(CardinalDirections.CardinalDirection.NORTH) && digs.has(CardinalDirections.CardinalDirection.EAST):
                    n.rotation.y = PI
                    n.position = pos + (Vector3.RIGHT + Vector3.FORWARD) * grid_size
                else:
                    push_error("%s cannot rotate %s to %s-%s, only orthogonal planar cardinals allowed, using default rotation" % [
                        name, _block_dug_two_bend.resource_path, CardinalDirections.name(digs[0]), CardinalDirections.name(digs[1])
                    ])
                    n.position = pos
                return n
            else:
                push_error("%s doesn't have a template for dug out cardinals %s - %s" % [
                    name, CardinalDirections.name(digs[0]), CardinalDirections.name(digs[1])
                ])
                return null
        3:
            
            var undug: Array[CardinalDirections.CardinalDirection] = Array(CardinalDirections.ALL_PLANAR_DIRECTIONS.filter(
                func (d: CardinalDirections.CardinalDirection) ->  bool: return !digs.has(d)
            ), TYPE_INT, "", null) as Array[CardinalDirections.CardinalDirection]
            var n: Node3D = _block_dug_three.instantiate()
            if undug.size() != 1:
                push_error("%s cannot rotate %s because expected only planar cardinals in %s, %s, %s. Using default rotation." % [
                    name, _block_dug_three.resource_path, CardinalDirections.name(digs[0]), CardinalDirections.name(digs[1]), CardinalDirections.name(digs[2])
                ])
                n.position = pos
                return n
            
            var undig: CardinalDirections.CardinalDirection = undug[0]    
            parent.add_child(n)
            match undig:
                CardinalDirections.CardinalDirection.SOUTH:
                    n.rotation.y = -PI * 0.5
                    n.position = pos + Vector3.FORWARD * grid_size
                CardinalDirections.CardinalDirection.WEST:
                    n.rotation.y = PI
                    n.position = pos + (Vector3.FORWARD + Vector3.RIGHT) * grid_size
                CardinalDirections.CardinalDirection.EAST:
                    n.position = pos
                CardinalDirections.CardinalDirection.NORTH:
                    n.rotation.y = PI * 0.5
                    n.position = pos + Vector3.RIGHT * grid_size
                _:
                    push_error("%s cannot rotate %s to %s undug, only planar cardinals allowed, using default rotation" % [
                        name, _block_dug_one.resource_path, CardinalDirections.name(undig),
                    ])
                    n.position = pos
            return n
        4:
            var n: Node3D = _block_dug_four.instantiate()
            parent.add_child(n)
            n.position = pos
            return n
            
        _:
            push_error("%s doesn't have a template for being dug out by %s directions %s" % [
                name, digs.size(), digs.map(func (c: CardinalDirections.CardinalDirection) -> String: return CardinalDirections.name(c))
            ])
            return null

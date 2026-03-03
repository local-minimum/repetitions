extends Node3D
class_name LooseTrackPosition

static func find_in_tree(node: Node) -> LooseTrackPosition:
    if node == null:
        return null

    if node is LooseTrackPosition:
        return node

    return find_in_tree(node.get_parent())

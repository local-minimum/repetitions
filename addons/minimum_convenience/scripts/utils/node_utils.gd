class_name NodeUtils

static func parentage(node: Node) -> Array[Node]:
    var parents: Array[Node]
    while node != null:
        node = node.get_parent()
        if node != null:
            parents.append(node)
    return parents

static func is_parent(node: Node, child: Node) -> bool:
    while child != null:
        if child == node:
            return true
        child = child.get_parent()
    return false
    
static func find_parent_types(node: Node, types: Array[String]) -> Node:
    for type: String in types:
        var parent: Node = find_parent_type(node, type)
        if parent != null:
            return parent

    return null

static func find_parent_type(node: Node, type: String) -> Node:
    if node == null:
        return null

    if node.is_class(type):
        return node
    else:
        var script: Script = node.get_script()
        if script != null:
            if script.get_global_name() == type:
                return node

            while script != null:
                script = script.get_base_script()
                if script != null && script.get_global_name() == type:
                    return node

    return find_parent_type(node.get_parent(), type)

static func body3d(node: Node) -> PhysicsBody3D:
    if node is PhysicsBody3D:
        return node
    
    elif node == null:
        return null
    
    return body3d(node.get_parent())

static func disable_physics_in_children(root: Node3D) -> void:
    if root is PhysicsBody3D:
        var body: PhysicsBody3D = root
        body.process_mode = Node.PROCESS_MODE_DISABLED
    elif root is CollisionShape3D:
        var shape: CollisionShape3D = root
        shape.disabled = true
        
    for shape: CollisionShape3D in root.find_children("", "CollsionShape3D"):
        shape.disabled = true

    for body: PhysicsBody3D in root.find_children("", "PhysicsBody3D"):
        body.process_mode = Node.PROCESS_MODE_DISABLED
    
static func enable_physics_in_children(root: Node3D, mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT) -> void:
    if root is PhysicsBody3D:
        var body: PhysicsBody3D = root
        body.process_mode = mode
    elif root is CollisionShape3D:
        var shape: CollisionShape3D = root
        shape.disabled = false
        
    for shape: CollisionShape3D in root.find_children("", "CollsionShape3D"):
        shape.disabled = false

    for body: PhysicsBody3D in root.find_children("", "PhysicsBody3D"):
        body.process_mode = mode

class_name RectUtils

static func corners(rect: Rect2, end_padding: float = 0) -> Array[Vector2]:
    var size: Vector2 = rect.size
    # print_debug(size)
    size.x -= sign(size.x) * end_padding
    size.y -= sign(size.y) * end_padding

    var pos: Vector2 = rect.position
    var end: Vector2 = pos + size
    return [
        pos,
        Vector2(pos.x, end.y),
        end,
        Vector2(end.x, pos.y),
    ]

static func shrink(rect: Rect2, x_amount: float, y_amount: float, keep_center: bool = false) -> Rect2:
    var size: Vector2 = rect.size
    size.x -= sign(size.x) * x_amount
    size.y -= sign(size.y) * y_amount
    if keep_center:
        @warning_ignore_start("unsafe_call_argument")
        return Rect2(rect.position + Vector2(sign(size.x) * 0.5 * x_amount, sign(size.y) * 0.5 * y_amount), size)
        @warning_ignore_restore("unsafe_call_argument")

    return Rect2(rect.position, size)

static func clamp_pointi(rect: Rect2i, pt: Vector2i) -> Vector2i:
    if rect.has_point(pt):
        return pt
    return pt.clamp(rect.position, rect.end - Vector2i.ONE)
    
static func translate_local(r: Rect2, from: Node2D, to: Node2D) -> Rect2:
    var p: Vector2 = to.to_local(from.to_global(r.position))
    var e: Vector2 = to.to_local(from.to_global(r.end))
    return Rect2(p.min(e), (e - p).abs())

extends Node
class_name DraftPool

@export var pool: Array[DraftOption]

func draft(count: int = 1) -> Array[DraftOption]:
    var available: Array[DraftOption] = Array(
        pool.filter(func (opt: DraftOption) -> bool: return !opt.consumed),
        TYPE_OBJECT,
        "Resource",
        DraftOption,
    )
    
    if available.is_empty():
        push_warning("Out of options in draft pool / all consumed")
        return []
    elif available.size() <= count:
        push_warning("Not enough options, returning everything %s" % [available])
        return available
        
    print_debug("[Draft Pool] options: %s" % [available])    
    var total_prob: float = 0.0
    var probs: Array[float] = []
    var idx: int = 0
    var available_count: int = available.size()
    
    if probs.resize(available_count) != OK:
        push_error("Failed to allocate probability array")
        return []
    
    for opt: DraftOption in available:
        total_prob += opt.draft_probability
        probs[idx] = total_prob
        idx += 1
    
    var drafts: Array[DraftOption] = []
    for _idx: int in range(count):
        if available_count < 1:
            push_error("No more rooms available %s we should have known this" % [available])
            return drafts
            
        var p: float = randf_range(0, probs[available_count - 1])
        var opt_idx: int = probs.find_custom(func (v: float) -> bool: return p <= v)
        
        if opt_idx < 0:
            push_warning("Unexpected option selection - option not found drawing one on unweighted random")
            opt_idx = randi_range(0, available_count - 1)
            
        drafts.append(available[opt_idx])
        available.remove_at(opt_idx)
        var diff: float = probs[opt_idx] if opt_idx == 0 else probs[opt_idx] - probs[opt_idx - 1]
        probs.remove_at(opt_idx)
        available_count -= 1
        for idx2: int in range(opt_idx, available_count):
            probs[opt_idx] -= diff
        
    return drafts    
    

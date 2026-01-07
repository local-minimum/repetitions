extends OccupancyConcurrencyRestriction
class_name OnlyOnEntityRestriction

@export var allow_transit: bool

func can_coexist(entity: GridEntity, others: Array[GridEntity], passing_through: bool) -> bool:
    return passing_through && allow_transit || others.is_empty() || others.size() == 1 && others.has(entity)

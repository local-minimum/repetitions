extends OccupancyConcurrencyRestriction
class_name NoConcurrencyRestriction

func can_coexist(_entity: GridEntity, _others: Array[GridEntity], _passing_through: bool) -> bool:
    return true

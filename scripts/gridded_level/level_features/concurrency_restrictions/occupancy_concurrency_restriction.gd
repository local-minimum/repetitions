@abstract extends Resource
class_name OccupancyConcurrencyRestriction

@abstract func can_coexist(entity: GridEntity, others: Array[GridEntity], passing_through: bool) -> bool

extends OccupancyConcurrencyRestriction
class_name LimitedSameClassSpaceRestriction

@export var max_coinhabitants: int = 4
@export var allow_transit: bool

func can_coexist(entity: GridEntity, others: Array[GridEntity], passing_through: bool) -> bool:
    if passing_through && allow_transit:
        return true

    if others.size() >= max_coinhabitants:
        return false

    var type: EntityFilter.EntityType = EntityFilter.get_entity_type(entity)

    return others.filter(
        func (e: GridEntity) -> bool:
            return type == EntityFilter.get_entity_type(e)
    ).size() == others.size()

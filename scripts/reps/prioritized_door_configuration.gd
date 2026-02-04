@abstract
extends Resource
class_name PrioritizedDoorConfiguration

class Applicability:
    ## Returns the priory of this configuration, the primary filter of what configurations
    ## will be considered
    var priority: int

    ## Weighted probability of invoking this configuration if several competing configurations
    ## are available after the priority filtering
    var weight: float

    ## If invoking the config will finalize configuration
    var finalizes: bool

    ## If there might be variants that could be executed during invoke
    ## this is an internal reference to which
    var application_version: int

    @warning_ignore_start("shadowed_variable")
    func _init(
        priority: int = 0,
        weight: float = 1.0,
        finalizes: bool = true,
        version: int = 0,
    ) -> void:
        @warning_ignore_restore("shadowed_variable")
        self.priority = priority
        self.weight = weight
        self.finalizes = finalizes
        application_version = version

## If config can be applied
@abstract func applicable(data: DoorData, other: Room3D) -> Applicability

## Returns true if could be performed
@abstract func invoke(version: int) -> bool

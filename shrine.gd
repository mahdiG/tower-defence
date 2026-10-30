extends StaticBody3D

signal destroyed()

@export var max_health: float = 1000.0

var health := 1000.0
var is_destroyed := false


func _ready() -> void:
	health = max_health


func take_damage(amount: float) -> void:
	if is_destroyed:
		return

	health = maxf(health - amount, 0.0)

	if health <= 0.0:
		is_destroyed = true
		destroyed.emit()

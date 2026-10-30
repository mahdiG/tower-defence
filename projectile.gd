extends Area3D

@export var speed := 25.0
@export var lifetime := 3.0

var damage := 10.0
var target: Node3D = null

@onready var lifetime_timer: Timer = $LifetimeTimer


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	lifetime_timer.wait_time = lifetime
	lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start()


func shoot(new_target: Node3D, new_damage: float) -> void:
	target = new_target
	damage = new_damage


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var target_position := target.global_position + Vector3.UP
	global_position = global_position.move_toward(target_position, speed * delta)

	if global_position.distance_squared_to(target_position) < 0.01:
		_hit(target)


func _on_body_entered(body: Node3D) -> void:
	_hit(body)


func _hit(body: Node3D) -> void:
	if is_queued_for_deletion():
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()

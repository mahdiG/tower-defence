extends CharacterBody3D

signal died()

@export var speed := 6
@export var basic_attack_damage := 10

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var attack_area: Area3D = $AttackArea

var health := 100.0
var shrine: StaticBody3D = null
var current_target: Node3D = null
var targets_in_range: Array[Node3D] = []
var isAttackOnCooldown := false


func _ready() -> void:
	attack_area.body_entered.connect(_on_target_entered_range)
	attack_area.body_exited.connect(_on_target_left_range)

	attack_cooldown_timer.one_shot = true


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	_update_target()

	if is_instance_valid(current_target):
		look_at(current_target.global_position)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		attack(current_target)
		return

	_move_to_shrine()


func _update_target() -> void:
	targets_in_range = targets_in_range.filter(is_instance_valid)

	# Keep attacking the current target until it dies or leaves the range.
	if is_instance_valid(current_target) and current_target in targets_in_range:
		return

	current_target = _find_closest_target()


func _find_closest_target() -> Node3D:
	var closest_target: Node3D = null
	var closest_distance := INF

	for target in targets_in_range:
		var distance := global_position.distance_squared_to(target.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = target

	return closest_target


func _move_to_shrine() -> void:
	if not is_instance_valid(shrine):
		return

	look_at(shrine.global_position)
	navigation_agent.target_position = shrine.global_position

	var next_position := navigation_agent.get_next_path_position()
	var new_velocity := global_position.direction_to(next_position) * speed

	if navigation_agent.avoidance_enabled:
		# This only works if avoidance is enabled in the navigation agent.
		navigation_agent.set_velocity(new_velocity)
	else:
		velocity = new_velocity

	move_and_slide()


func initialize(spawn_position: Vector3, initial_target: StaticBody3D) -> void:
	shrine = initial_target
	position = spawn_position


func attack(target: Node3D) -> void:
	if isAttackOnCooldown:
		return

	if target.has_method("take_damage"):
		target.take_damage(basic_attack_damage)

	isAttackOnCooldown = true
	attack_cooldown_timer.start()


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		die()


func die() -> void:
	died.emit()
	queue_free()


func _on_target_entered_range(target: Node3D) -> void:
	if target in targets_in_range:
		return

	targets_in_range.append(target)

	# The first target that enters becomes the attack target.
	if not is_instance_valid(current_target):
		current_target = target


func _on_target_left_range(target: Node3D) -> void:
	targets_in_range.erase(target)


func _on_navigation_agent_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity


func _on_attack_cooldown_timer_timeout() -> void:
	isAttackOnCooldown = false

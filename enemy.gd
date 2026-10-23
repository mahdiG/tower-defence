extends CharacterBody3D

signal died()

@export var speed := 6

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer

var health := 100
var target: StaticBody3D
var isAttackOnCooldown := false

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	look_at(target.global_position)
		
	navigation_agent.target_position = target.position
	var current_location := global_transform.origin
	var next_location := navigation_agent.get_next_path_position()
	var new_velocity := current_location.direction_to(next_location) * speed
	
	if navigation_agent.avoidance_enabled:
		# This only works if avoidance is enable in navigation agent
		navigation_agent.set_velocity(new_velocity)
	else:
		velocity = new_velocity
	
	move_and_slide()

func initialize(spawn_position: Vector3, initial_target: StaticBody3D) -> void:
	target = initial_target
	position = spawn_position

func _on_navigation_agent_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity

func _on_navigation_agent_target_reached() -> void:
	print("reached target")

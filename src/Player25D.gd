extends CharacterBody3D

# This is the highest step we can overcome
const _max_step := .25

var pressed: Dictionary[int, bool] = {}

func is_pressed(key: int) -> bool:
	return key in pressed && pressed[key]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Shoot a raycast right in front of the velocity vector, to prevent a collision before it even happens!
func step_up(delta: float) -> void:
	if !is_on_floor(): return

	var vel := velocity
	vel.y = 0

	# Velocity is too small for us to care...
	if vel.length_squared() < .01: return

	var collision := KinematicCollision3D.new()

	# If we *can* move, we abort mission
	if !test_move(transform, velocity * delta, collision): return

	var start := collision.get_position() + vel.normalized() * .25
	start.y = global_position.y
	start += Vector3.UP * _max_step

	var step_hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(start, start + Vector3.DOWN * Vector3.UP * _max_step * 5)
	)
	if !step_hit: return

	var end := step_hit["position"] as Vector3

	# The ray was stuck in an object, we can't overcome this step
	if start.distance_squared_to(end) < .00001: return
	# Somehow, we hit the darn floor
	if end.y - global_position.y < .001: return

	velocity.y = 0

	position += Vector3.UP * ((end.y - global_position.y) + .01)

func _physics_process(delta: float) -> void:
	velocity *= Vector3(.85, .99, .85)

	var new_velocity := Vector3.ZERO
	if is_pressed(KEY_W): new_velocity += Vector3.FORWARD
	if is_pressed(KEY_S): new_velocity += Vector3.BACK
	if is_pressed(KEY_A): new_velocity += Vector3.LEFT
	if is_pressed(KEY_D): new_velocity += Vector3.RIGHT
	new_velocity = new_velocity.normalized()
	velocity += new_velocity * 25 * delta
	velocity += Vector3(0, -9.9 * delta, 0)

	if is_pressed(KEY_SPACE) && is_on_floor(): velocity += Vector3.UP * 5

	step_up(delta)
	move_and_slide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		pressed[event.keycode] = event.pressed

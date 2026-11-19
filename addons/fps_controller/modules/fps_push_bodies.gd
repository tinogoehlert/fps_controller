class_name FPSPushBodies
extends FPSModule
## Pushes the RigidBody3Ds the player walks into, at walking speed times player_mass / mass at most.

## Bodies up to this mass get the full walking speed.
@export_range(1.0, 1000.0, 1.0, "suffix:kg") var player_mass := 80.0
## Above 1 shoves light bodies ahead.
@export_range(0.0, 3.0, 0.05) var strength := 1.0
## Pushing at once tips bodies over.
@export_range(1.0, 200.0, 1.0, "suffix:m/s²") var acceleration := 30.0
## Above the feet. Higher tips boxes over, the floor holds their bottom back.
@export_range(0.0, 2.0, 0.05, "suffix:m") var push_height := 0.3


## The collisions are from the last move.
func physics_update(delta: float) -> void:
	var pushed := {}
	for i in controller.get_slide_collision_count():
		var collision := controller.get_slide_collision(i)
		var body := collision.get_collider() as RigidBody3D
		if not body or body.freeze or pushed.has(body):
			continue
		var direction := -collision.get_normal()
		direction.y = 0.0
		if direction.length_squared() < 0.01:
			continue  # standing on it
		direction = direction.normalized()
		pushed[body] = true
		# not the velocity: the slide removes the part into the body
		var wish := controller.wish_velocity.dot(direction)
		var target := wish * strength * minf(player_mass / body.mass, 1.0)
		var body_speed := body.linear_velocity.dot(direction)
		if target <= body_speed:
			continue
		var gain := minf(target - body_speed, acceleration * delta)
		# at the contact for spin, never above the center
		var offset := collision.get_position() - body.global_position
		offset.y = minf(controller.global_position.y + push_height - body.global_position.y, 0.0)
		body.apply_impulse(direction * gain * body.mass, offset)
		# keep leaning in: the move ends at the body, so contact holds every frame
		var lean := controller.velocity + direction * maxf(wish - controller.velocity.dot(direction), 0.0)
		var flat := Vector2(lean.x, lean.z).limit_length(maxf(controller.wish_velocity.length(), controller.horizontal_speed()))
		controller.velocity = Vector3(flat.x, lean.y, flat.y)

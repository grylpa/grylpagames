extends RigidBody2D

# Clamp speed INSIDE the physics step (after contacts are solved), so a pinch
# between the tool and a wall can't fling the ball. Clamping in the level's
# _physics_process runs before the solver and is too late. Position is also
# corralled each frame by level.gd (_corral_balls) as a hard on-screen guarantee.

var max_speed: float = 420.0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var v: Vector2 = state.linear_velocity
	var sp: float = v.length()
	if sp > max_speed:
		state.linear_velocity = v * (max_speed / sp)

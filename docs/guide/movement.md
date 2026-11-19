# Movement

## Walking

`FPSGroundState` moves like Quake on the floor: `friction` slows the player down (below `stop_speed` it stops
as if at `stop_speed`), `acceleration` brings them up to the wish speed: `walk_speed`, `sprint_speed` while
`fps_sprint` is held, `crouch_speed` crouched. A half tilted stick asks for half the speed.

`FPSAirState` keeps the momentum and only adds `air_speed` along the input, capped at `air_speed_cap` (1 m/s by
default) in that direction. Like in Quake, turning while strafing in the air gains speed: air strafing and, with
jumps right at landing, bunny hopping.

States and modules use the same helpers on the controller: `accelerate(direction, wish_speed, acceleration,
delta, speed_cap)`, `apply_friction(friction, stop_speed, delta)`, `apply_gravity(delta)` and
`horizontal_speed()`. `accelerate()` records the speed it was asked for in `controller.wish_velocity`: where the
player wants to go before walls slow the body down.

## Jumping

`jump_velocity` and `gravity` set the jump, 8.4 m/s and 25 m/s² reach about 1.4 m. A press counts for
`jump_buffer_time` seconds, so pressing it a moment before landing still jumps. For `coyote_time` seconds after
walking off a ledge the Air state still jumps. With `auto_jump` holding jump jumps again at every landing.

Jumps go through `controller.consume_jump()`, so a state and a module never react to the same press.
`controller.jump(speed)` jumps and sends `jumped`.

`FPSDoubleJump` gives `air_jumps` more jumps in the air, at `velocity_scale` of the jump. With
`redirect_momentum` each one turns the speed the player has into the direction they steer.

## Crouching and stairs

Holding `fps_crouch` shrinks the collision to `crouch_height`; standing up waits until there is room above. The
eyes follow at `crouch_smoothing`. `controller.set_crouched(value)` does the same from code, `is_crouched` says
how it is.

Steps up to `step_height` are walked up and down without a jump. The camera does not jump with them, it follows
at `step_smoothing`; `stepped(height)` reports each step.

## Sliding

`FPSSlideState` starts when crouch is pressed while running at `min_entry_speed` or faster, or when landing with
crouch held. It adds `boost` up to `max_speed`, slows down with `friction` and ends after `max_duration`, below
`exit_speed`, when crouch is let go or the floor is gone. After a slide the next one waits `cooldown` seconds.
FPSViewRoll leans the view into slides.

## Swimming

`FPSSwimState` swims while `submerge_depth` of the body is in an `Area3D` of its `liquid_group` (`liquid`), half
the height by default like Quake swims from the waist. The player swims where they look, jump rises, crouch
sinks; without input they sink at `sink_speed`. Jumping with the head above the surface climbs out with
`exit_jump_velocity`.

## Ladders

`FPSLadderState` climbs while the feet or the waist are in an `Area3D` of its `ladder_group` (`ladder`):

| Input | |
|---|---|
| forward | climbs up; while looking down further than `look_down_angle` (30°) it climbs down |
| back | climbs down |
| sideways | moves along the ladder at `strafe_speed` |
| jump | lets go, back from the view, with `jump_off_speed` |
| nothing | holds on, without gravity |

Grabbing a ladder stops the player, so backing off a ledge onto a ladder holds on. On the floor only climbing
up takes the ladder, walking past it stays walking. After letting go the ladder waits `regrab_delay` before it
catches the player again. Climbing up also pushes forward, into the wall and past the top onto the ledge: let
the volume end a little above the upper floor.

## Pushing bodies

A `CharacterBody3D` stops at a `RigidBody3D` like at a wall. `FPSPushBodies` pushes the bodies the player walks
into: bodies up to `player_mass` get the walking speed, heavier ones `player_mass / mass` of it (twice the
weight, half the speed), times `strength`, and the player walks as fast as they give way. They speed up by
`acceleration` and are pushed `push_height` above the feet: pushed higher, the floor's friction tips a box
over. A frozen body is not pushed.

## Teleporting

`controller.teleport(transform)` moves the player there, facing the transform's direction, looking straight
ahead and standing still.

## Writing a state

A state says when it applies and what it does to the velocity. It goes into the `FPSStateMachine` next to the
others:

```gdscript
class_name FPSJetpackState
extends FPSState


func _init() -> void:
	priority = 12


func can_enter() -> bool:
	return not controller.is_on_floor() and controller.input.jump_held


func can_exit() -> bool:
	return not can_enter()


func physics_update(delta: float) -> void:
	controller.velocity.y = move_toward(controller.velocity.y, 3.0, 20.0 * delta)
```

The states that ship have these priorities, higher ones are asked first:

| State | `priority` |
|---|---|
| Swim | 20 |
| Ladder | 15 |
| Slide | 10 |
| Aim | 5 |
| Ground, Air | 0 |

`enter(previous)` and `exit(next)` run on a switch, `controller` and `machine` are set before the first tick.
The state machine sends `state_changed(previous, current)`, `machine.current` is the active state.

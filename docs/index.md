# FPS Controller

A first-person controller for Godot with Quake-style movement: acceleration and friction like Quake, air
strafing, bunny hopping with `auto_jump`, stair stepping. Everything beyond walking is a part to add or leave
out.

| | |
|---|---|
| Godot | 4.5 or newer |
| Language | GDScript, no dependencies |
| Input | mouse and keyboard, gamepad; rebindable |

## Install

Copy `addons/fps_controller` into the project and enable **FPS Controller** under *Project > Project Settings >
Plugins*. Enabling it adds the `fps_*` input actions to the project, see
[Getting started](guide/getting-started.md).

## Structure

```
FPSController (CharacterBody3D)   look, gravity, jump buffer, coyote time, crouch, stair stepping
├─ Collision                      CylinderShape3D or CapsuleShape3D, origin at the feet
├─ Head                           pitch, eye height, stair smoothing
│  └─ Camera
│     └─ WeaponMount              the weapon, from FPSViewmodel.model_scene
├─ StateMachine                   the prefab's: Ground and Air
├─ States      FPSStateMachine    optional, your own, assigned to state_machine
│  ├─ Ground   FPSGroundState
│  ├─ Air      FPSAirState
│  ├─ Aim      FPSAimState        aim down sights: slower on the floor, zooms, also in the air
│  ├─ Slide    FPSSlideState
│  ├─ Ladder   FPSLadderState     climbs Area3Ds in its ladder_group
│  └─ Swim     FPSSwimState       liquids are Area3Ds in its liquid_group
├─ DoubleJump  FPSDoubleJump      modules, all optional
├─ HeadBob     FPSHeadBob
├─ ViewRoll    FPSViewRoll
├─ WeaponSway  FPSWeaponSway
├─ Viewmodel   FPSViewmodel
├─ AimAssist   FPSAimAssist
├─ Recoil      FPSRecoil
├─ ScreenShake FPSScreenShake
└─ PushBodies  FPSPushBodies
```

**States** (`FPSState`) are exclusive movement modes. Every physics tick the state machine asks the current
state `can_exit()`; if so, the first other state (highest `priority`) whose `can_enter()` returns true takes
over. A new state only describes when it applies, the others never reference it.

**Modules** (`FPSModule`) add to whatever state is active. Every `FPSModule` below the controller is found on
its own and gets `physics_update()` after the state. Visual modules work in `_process()` and on the
controller's signals. Modules sharing a node split it: FPSHeadBob only sets the camera's position, FPSViewRoll
only its roll.

### Tick order

1. read the input (`controller.input`, `wish_dir`, jump buffer)
2. the active state changes the velocity
3. the modules
4. move: step up, `move_and_slide()`, step down

## Pages

- [Getting started](guide/getting-started.md): the prefab, input actions, mouse and gamepad
- [Movement](guide/movement.md): walking, jumping, crouching, stairs, sliding, swimming, ladders, pushing bodies, own states
- [Camera](guide/camera.md): field of view and zoom, aiming, head bob, footsteps, landing, view roll, screen shake
- [Weapons](guide/weapons.md): viewmodel, weapon sway, recoil, aim assist
- [Options](guide/options.md): settings players change, saved, and key bindings
- [Reference](reference/nodes.md): every class with its properties, methods and signals

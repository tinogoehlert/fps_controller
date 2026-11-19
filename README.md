# FPS Controller for Godot

![LGBTQ+ Friendly][badge-lgbtq]
![Trans Rights][badge-trans]
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A first-person controller for Godot 4.5+ with Quake-style movement, built from parts: exclusive movement
states (ground, air, aim, slide, ladder, swim) and optional modules (head bob, weapon sway, viewmodel, recoil,
screen shake, aim assist, pushing bodies). Mouse and gamepad, rebindable, with options a menu can save.

Written in GDScript, no dependencies.

## Install

Copy `addons/fps_controller` into your project, enable **FPS Controller** in the project settings' plugins and
instance `addons/fps_controller/fps_controller.tscn` in a level.

The documentation is in [docs/](docs/index.md).

[badge-trans]: https://pride-badges.pony.workers.dev/static/v1?label=trans%20rights&stripeWidth=6&stripeColors=5BCEFA,F5A9B8,FFFFFF,F5A9B8,5BCEFA
[badge-lgbtq]: https://pride-badges.pony.workers.dev/static/v1?label=lgbtq%2B%20friendly&stripeWidth=6&stripeColors=E40303,FF8C00,FFED00,008026,24408E,732982

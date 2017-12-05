package systems;

#if imgui
import imgui.Input;
#end
import components.Transform;
import math.Vec3;
import math.Bounds;
import math.Intersect;
import Debug.line;
import actor.TweenType;
import components.Player.TrickState;

import components.Trigger.TriggerState;

@:publicFields
class Trigger extends System {
	var player: Null<Entity>;

	override function filter(e: Entity) {
		if (e.player != null) {
			this.player = e;
		}
		return e.trigger != null && e.transform != null;
	}

	// static function line(v0: Vec3, v1: Vec3, r: Float, g: Float, b: Float) {
	// 	if (Main.showing_menu(Main.WindowType.EditorUI)) {
	// 		Debug.line(v0, v1, r, g, b);
	// 	}
	// }

	static function register_signals() {
		Signal.register("Test", function(params) {
			var e:  Entity       = params.e;
			var ts: TriggerState = params.ts;


			if (ts == TriggerState.Entered) {
				trace("Entered");
				e.trigger.enabled = false; // disable trigger to not trigger it multiple times
				var new_pos = e.transform.position.copy();
				new_pos.z += 1;

				TimerAction.add(1, e.transform.position, new_pos, TweenType.OutCubic, function(){
					Signal.emit("enable-trigger", { e:e });
					e.transform.update();
				});
			}

			if (ts == TriggerState.Inside) {
				trace("Inside");
			}

			if (ts == TriggerState.Left) {
				trace("Left");
			}
		});

		Signal.register("enable-trigger", function(params) {
			params.e.trigger.enabled = true;
		});



		////////////////////////////////////////////////////////////////////////////////////////




		Signal.register("animation-grind", function(params) {
			trace("grind");
			var e: Entity = params.e;
			var tl        = e.animation.timeline;
			var gr        = e.player.get_track(tl, "grind");

			if (!tl.find_track(gr)) {
				tl.reset();
				tl.play(gr);
			}
		});

		Signal.register("animation-skate", function(params) {
			trace("skate");
			var e: Entity = params.e;
			var tl        = e.animation.timeline;
			var gr        = e.player.get_track(tl, "skate");

			if (!tl.find_track(gr)) {
				tl.reset();
				tl.play(gr);
			}
		});

		Signal.register("animation-air-trick-a", function(params) {
			trace("air a");
			var e: Entity = params.e;
			var tl        = e.animation.timeline;
			var gr        = e.player.get_track(tl, "trick.a");

			if (!tl.find_track(gr)) {
				tl.reset();
				tl.play(gr);
			}

			gr.callback = function() {
				Signal.emit("animation-skate", params);
			};
		});

		Signal.register("animation-rail-trick-a", function(params) {
			trace("rail a");
			var e: Entity = params.e;
			var tl        = e.animation.timeline;

			if (e.player.trick_state == TrickState.TrickA) {
				e.player.trick_state = TrickState.None;
				var gr = e.player.get_track(tl, "grind");

				if (!tl.find_track(gr)) {
					tl.reset();
					tl.play(gr);
				}
			} else {
				e.player.trick_state = TrickState.TrickA;
				var gr = e.player.get_track(tl, "trick.a");

				if (!tl.find_track(gr)) {
					tl.reset();
					tl.play(gr);
				}

				gr.callback = function() {
					Signal.emit("animation-rail-grind-a", params);
				};
			}

			e.transform.velocity.normalize();
			e.transform.velocity *= 10;
		});

		Signal.register("animation-rail-grind-a", function(params) {
			trace("grind a");
			var e: Entity = params.e;
			var tl        = e.animation.timeline;
			var gr        = e.player.get_track(tl, "grind.a");

			if (!tl.find_track(gr)) {
				tl.reset();
				tl.play(gr);
			}
		});
	}

	static function in_front_of(p: Transform, e: Transform, max_distance: Float, min_angle: Float) {
		var dir = p.orientation * -Vec3.unit_y();

		var ppos = p.as_absolute();
		var epos = e.as_absolute();
		var p2e = epos - ppos;
		p2e.normalize();

		if (Vec3.dot(p2e, dir) > min_angle) {
			var in_range = Vec3.distance(ppos, epos) <= max_distance;
			var offset = new Vec3(0, 0, 0.001);
			if (in_range) {
				line(ppos + offset, ppos + p2e + offset, 0, 1, 0.5);
			}
			else {
				line(ppos + offset, ppos + p2e + offset, 1, 0, 0.5);
			}
			return in_range;
		}

		return false;
	}

	override function update(entities: Array<Entity>, dt: Float) {
#if imgui
		if (Input.get_want_capture_keyboard()) {
			return;
		}
#end

		if (this.player == null) {
			return;
		}

		var p     = this.player;
		var ppos  = p.transform.as_absolute();
		var dir   = p.transform.orientation.apply_forward();
		var range = new Vec3(0, 0, 0);
		// line(ppos, ppos + dir, 1, 1, 0);

		for (e in entities) {
			// TODO: fix triggering across world wrap
			var trigger = e.trigger;
			var tpos    = e.transform.as_absolute();
			var hit     = false;

			if (!trigger.enabled) {
				continue;
			}

			switch (trigger.type) {
				case Radius:
					hit = Vec3.distance(tpos, ppos) <= trigger.range;
				case Volume:
					for (i in 0...3) {
						range[i] = trigger.range;
					}
					hit = Intersect.point_aabb(ppos, Bounds.from_extents(tpos - range, tpos + range));
				case RadiusInFront:
					hit = in_front_of(p.transform, e.transform, trigger.range, 1-trigger.max_angle);
			}

			if (hit) {
				if (!trigger.inside) {
					trigger.inside = true;
					Signal.emit(trigger.cb, { e:e, ts:TriggerState.Entered });
				}

				Signal.emit(trigger.cb, { e:e, ts:TriggerState.Inside });
			} else if (trigger.inside) {
				trigger.inside = false;
				Signal.emit(trigger.cb, { e:e, ts:TriggerState.Left });
			}
		}

		TimerAction.update(dt);
	}
}

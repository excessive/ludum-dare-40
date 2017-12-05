/*

Collision Problems
==================

* "lifting" seems to not work very well, you can phase through ankle-height ledges

*/

package systems;

import imgui.Input;
import components.Rail;
import components.Player;
import math.Vec2;
import math.Vec3;
import math.Quat;
import math.Ray;
import math.Capsule;
import math.Intersect;
import GameInput.Action;
import collision.CollisionPacket;
import collision.Response;
#if imgui
import imgui.Widget;
#end
import Profiler.SegmentColor;

// give me a better name thx
class RailsHelper {
	public static function get_tile_rails(player: Entity): Array<Rail> {
		var rails = [];
		var vtiles = World.get_adjacent_tiles(player.transform.as_absolute());

		for (vtile in vtiles) {
			var vtile  = World.virtual_tile_at(player.transform.as_absolute());
			var tile = vtile.world_tile;

			for (e in tile.entities) {
				if (e.rails != null) {
					for (rail in e.rails) {
						var r       = rail.copy();
						r.mtx       = e.transform.mtx;
						r.capsule.a = r.capsule.a;
						r.capsule.b = r.capsule.b;
						rails.push(r);
					}
				}
			}
		}

		return rails;
	}

	public static function closest_end_of_rail(position: Vec3, rail: Rail) {
		var near    = rail.capsule.a;
		var far     = rail.capsule.b;
		var closest = rail.prev;

		// Swap if needed
		if (Vec3.distance(rail.capsule.a, position) > Vec3.distance(rail.capsule.b, position)) {
			return {
				near: far,
				far: near,
				closest: rail.next
			}
		}

		return { near: near, far: far, closest: closest }
	}

	public static function transfer_rail(player: Entity, rail: Rail): Bool {
		var data = closest_end_of_rail(player.transform.as_absolute(), rail);

		if (data.closest != null) {
			var velocity = (data.closest.capsule.a + data.closest.capsule.b) / 2 - data.near;
			velocity.normalize();
			velocity *= player.transform.velocity.length();

			player.transform.position = World.to_local(data.near);
			player.transform.velocity = velocity;
			player.player.rail = data.closest;

			return true;
		}

		return false;
	}

	public static function scan_for_rail(player: Entity, rails: Array<Rail>): Bool {
		var reject = player.player.rail;

		// haha fuck you scan all the things
		var ppos = player.transform.as_absolute();
		var player_capsule = new Capsule(ppos, ppos, player.player.rail_attach_radius);

		for (rail in rails) {
			if (rail == reject) { continue; }

			var result = Intersect.capsule_capsule(player_capsule, rail.capsule);

			if (result != null) {
				var velocity = player.transform.velocity.copy();
				velocity.normalize();

				var to_rail = result.p2 - ppos;
				to_rail.normalize();

				// do not attach to a rail you are moving away from
				var power = Vec3.dot(to_rail, velocity);
				if (power < 0) { break; }

				var direction = rail.capsule.b - rail.capsule.a;
				var new_velocity = Vec3.project_on(player.transform.velocity, direction);

				// don't attach if your speed will drop too much or you'll be going too slow to stay on
				var nvl = new_velocity.length();
				if (nvl < player.transform.velocity.length() / 5 || nvl < player.player.rail_stick_min) {
					break;
				}

				// maintain speed going on to next rail
				if (reject != null) {
					var rail_center = (rail.capsule.a + rail.capsule.b) / 2;
					new_velocity    = rail_center - result.p2;
					new_velocity.normalize();
					new_velocity   *= player.transform.velocity.length();
				}

				player.transform.velocity = new_velocity;
				player.transform.position = World.to_local(result.p2);
				player.player.rail = rail;

				return true;
			}
		}

		return false;
	}
}

@:publicFields
class PlayerController extends System {
	static var follow_camera = false;
	static var follow_real   = follow_camera;

	static var mx:  Float = 0;
	static var my:  Float = 0;
	static var now: Float = 0;

	public static function mouse_moved(dx: Float, dy: Float) {
		mx = dx;
		my = dy;
	}

	static function calc_jump(h: Float, xh: Float, vx: Float, max: Float) {
		var g:  Float = -2 * h * Math.pow(vx, 2) / Math.pow(xh, 2); // gravity
		var v0: Float =  2 * h * vx     / xh;                       // initial vertical velocity
		var th: Float = xh / vx;

		// Low velocity, fix jump height
		if (vx < 0.25) {
			th = xh / max;
			g  = -2 * h / Math.pow(th, 2);
			v0 = -g * th;
		}

		return { g:g, v0:v0, th:th };
	}

	static function jump(player: Player, t: Float) {
		var h:     Float = 2.5;
		var xh:    Float = 5;
		var speed: Float = 1;
		var vx:    Float = Math.abs(player.jump.speed);
		var p0:    Float = player.jump.z_offset;

		var r = calc_jump(h, xh, vx, player.speed);
		var g:  Float = r.g;
		var v0: Float = r.v0;
		var th: Float = r.th;

		if (player.jump.falling) {
			speed = 1;
			t += th;
			p0 -= h;
		} else if (t > th && vx > 0) {
			speed = 1;
		}

		xh /= speed;
		var thh: Float = th;
		r = calc_jump(h, xh, vx, player.speed);
		g  = r.g;
		v0 = r.v0;
		th = r.th;
		t -= (thh - th);

		return { z:(g / 2 * Math.pow(t, 2)) + (v0 * t) + p0, h:h };
	}

	override function filter(e: Entity) {
		if (e.player != null && e.transform != null) {
			return true;
		}
		return false;
	}

	inline function show_debug() {
		return Main.showing_menu(Main.WindowType.EditorUI);
	}

	function adjust_camera(e: Entity) {
		return;

		Profiler.push_block("camera");
		var pos = e.transform.position;
		var dir = -e.camera.direction;
		var ray = new Ray(
			new Vec3(pos.x, pos.y, pos.z - e.camera.orbit_offset.y),
			new Vec3(dir.x, dir.y, dir.z)
		);
		var hit = World.nearest_hit(ray);
		e.camera.clip_distance = 999;
		if (hit != null) {
			e.camera.clip_distance = hit.distance;
		}

		if (show_debug()) {
			var r2 = new Ray(
				pos + new Vec3(0, 0, 0.5),
				-Vec3.up()
			);
			hit = World.nearest_hit(r2);
			if (hit != null) {
				var n = hit.triangle.normal();
				var fwd = e.transform.orientation.apply_forward();
				var right = Vec3.cross(n, fwd);
				fwd = Vec3.cross(right, n);
				Debug.axis(hit.point, right, fwd, n, 0.5);
			}
		}
		Profiler.pop_block();
	}

	function update_animation(e: Entity, move: Vec3, accel: Vec3, dt: Float) {
		if (e.animation == null || e.animation.timeline == null) {
			return;
		}

		var tl = e.animation.timeline;
		var p = e.player;

		var ml = accel.length();

		if (!p.on_ground) {
			var fall = p.get_track(tl, "fall");
			var jump = p.get_track(tl, "jump");
			if (!tl.find_track(fall) && !tl.find_track(jump)) {
				tl.reset();
				tl.play(fall);
			}
			return;
		}

		if (p.rail != null) {
			if (p.trick_state != None) {
				return;
			}
			// grinding
			var gr = p.get_track(tl, "grind");
			if (!tl.find_track(gr)) {
				// tl.reset();
				// tl.play(gr);
				tl.transition(gr, 0.15);
			}
		}
		// skating fast
		else if (ml > 0.975 && e.transform.velocity.length() > 5) {
			var rt = p.get_track(tl, "skate");
			if (!tl.find_track(rt)) {
				// tl.reset();
				tl.transition(rt, 0.2);
				// tl.play(rt); // TODO: fix transition
			}
		}
		// skating slow
		else if (ml > 0.05) {
			var st = p.get_track(tl, "slow");
			if (!tl.find_track(st)) {
				// tl.reset();
				tl.transition(st, 0.2); // TODO: fix transition
			}
		}
		// idle
		else {
			var it = p.get_track(tl, "idle");
			if (!tl.find_track(it)) {
				// tl.reset();
				tl.transition(it, 0.2); // TODO: fix transition
			}
		}
	}

	function update_camera(e: Entity, dt: Float) {
		if (e.camera == null) {
			return;
		}

		e.camera.rotate_xy(mx, -my);
		mx = 0;
		my = 0;

		// stick inputs are relative and don't factor dt by themselves, unlike mouse.
		var sens = 500 * dt;
		var rstick = GameInput.view_xy();
		rstick.y *= -1;
		e.camera.rotate_xy(rstick.x * sens, rstick.y * sens);

		Render.camera = e.camera;
	}

	function dump_packet(packet: CollisionPacket) {
#if imgui
		Widget.input_float3("e_base_point", packet.e_base_point.x, packet.e_base_point.y, packet.e_base_point.z);
		Widget.input_float3("e_norm_velocity", packet.e_norm_velocity.x, packet.e_norm_velocity.y, packet.e_norm_velocity.z);
		Widget.input_float3("e_position", packet.e_position.x, packet.e_position.y, packet.e_position.z);
		Widget.input_float3("e_radius", packet.e_radius.x, packet.e_radius.y, packet.e_radius.z);
		Widget.input_float3("e_velocity", packet.e_velocity.x, packet.e_velocity.y, packet.e_velocity.z);
		Widget.input_float3("r3_position", packet.r3_position.x, packet.r3_position.y, packet.r3_position.z);
		Widget.input_float3("r3_velocity", packet.r3_velocity.x, packet.r3_velocity.y, packet.r3_velocity.z);
		Widget.input_float3("intersection_point", packet.intersect_point.x, packet.intersect_point.y, packet.intersect_point.z);
		Widget.value("nearest_distance", packet.nearest_distance);
		Widget.value("depth", packet.depth);
		Widget.value("grounded", packet.grounded? 1 : 0);
		Widget.value("found_collision", packet.found_collision? 1: 0);
#end
	}

	override function process(e: Entity, dt: Float) {
		now += dt;

#if imgui
		if (Input.get_want_capture_keyboard()) {
			return;
		}
#end

		update_camera(e, dt);

		// Move player
		var stick = GameInput.move_xy();
		var move = new Vec3(stick.x, stick.y, 0);

		if (!e.player.on_ground) {
			// move *= 0.5;
		}

		var ml = move.length();
		if (move.length() > 1) {
			move.normalize();
			ml = 1;
			stick.x = move.x;
			stick.y = move.y;
		}

		move = -move;

		// Jump
		if (GameInput.pressed(Action.Jump)) {
		// bhop
		// if (GameInput.get_value(Action.Jump) > 0) {
			if (!e.player.jump.jumping && e.player.on_ground) {
				if (e.animation != null && e.animation.timeline != null) {
					var tl = e.animation.timeline;
					var jump = e.player.get_track(tl, "jump");
					var fall = e.player.get_track(tl, "fall");
					jump.callback = function() {
						tl.reset();
						tl.play(fall);
					}
				}
				e.player.rail = null;
				e.player.on_ground = false;
				// var jh = e.transform.velocity.length();
				e.transform.velocity.z += 7.5;
				e.transform.position.z += e.transform.velocity.z * dt;
				// e.player.jump.jumping  = true;
				// NB: start this one frame in the past so that the jump offset isn't 0 on the initial frame
				// e.player.jump.start    = now - dt;
				// e.player.jump.z_offset = e.transform.position.z;
				// e.player.jump.speed    = move.length() * e.player.speed;
			}
		}

		// Fall
		if (!e.player.jump.jumping && !e.player.jump.falling && !e.player.on_ground) {
			// e.player.jump.falling  = true;
			// e.player.jump.start    = now;
			// e.player.jump.z_offset = e.transform.position.z;
			// e.player.jump.speed    = move.length() * e.player.speed;
		}

		var snap_cancel = false;
		var weight      = e.player.turn_weight;
		var accel       = e.player.accel;

		update_animation(e, move, accel, dt);

		var nudge = 0.0001;
		var angle: Float = new Vec2(accel.x, accel.y + nudge).angle_to() + Math.PI / 2;

		// Orient player
		var move_orientation:   Quat = e.camera.orientation * Quat.from_angle_axis(angle, Vec3.up());
		move_orientation.x = 0;
		move_orientation.y = 0;
		move_orientation.normalize();
		var move_direction = move_orientation.apply_forward();


		if (move.length() > 0) {
			var snap_to: Quat = e.camera.orientation * Quat.from_angle_axis(angle, Vec3.up());

			if (e.transform.snap) {
				var current = e.transform.snap_to.apply_forward();
				var next    = snap_to.apply_forward();
				var from    = Vec3.dot(current, e.camera.direction);
				var to      = Vec3.dot(next, e.camera.direction);

				if (from != to && Math.abs(from) - Math.abs(to) == 0) {
					e.transform.orientation = e.transform.snap_to.copy();
				}
			}

			e.transform.snap    = true;
			e.transform.snap_to = snap_to;
			e.transform.slerp   = 0;
		}

		if (e.transform.snap) {
			e.transform.orientation = Quat.slerp(e.transform.orientation, e.transform.snap_to, 16 * dt);
			e.transform.orientation.x = 0;
			e.transform.orientation.y = 0;
			e.transform.orientation.normalize();
			e.transform.slerp += dt;

			if (e.transform.slerp >= 0.5) {
				e.transform.slerp = 0;
				e.transform.snap  = false;
				e.transform.snap_to.identity();
			}
		}

		if (e.transform.snap && snap_cancel) {
			e.transform.orientation   = e.transform.snap_to.copy();
			e.transform.orientation.x = 0;
			e.transform.orientation.y = 0;
			e.transform.orientation.normalize();

			e.transform.slerp = 0;
			e.transform.snap  = false;
			e.transform.snap_to.identity();
		}

		if (follow_camera) {
			e.camera.orientation = Quat.slerp(e.camera.orientation, e.transform.orientation, dt*2);
			e.camera.direction   = e.camera.orientation.apply_forward();
		}

		if (ml > 0) {
			// accelerating
			if (e.player.accel.length() <= ml) {
				e.player.accel += move * dt * weight;
				e.player.accel.trim(ml);
			}
		} else {
			// decelerating
			e.player.accel *= 1.0 - dt * weight;
		}

		if (e.player.accel.length() > 1) {
			e.player.accel.normalize();
		}

		var old_position = e.transform.position;
		var friction     = e.player.friction;

		// Player velocity

		// ignore velocity change while on rail
		// var speed_limit: Float = 1;
		if (e.player.rail == null) {
			// a = f / m
			e.transform.velocity += (move_direction * ml * e.player.speed) / e.player.mass;
		}
		// 	speed_limit = 6;
		// } else {
		// 	speed_limit = 15;
		// }

		// if (e.transform.velocity.length() > speed_limit) {
		// 	e.transform.velocity.normalize();
		// 	e.transform.velocity *= speed_limit;
		// }

		// World Collision
		if (e.player.rail == null || e.player.jump.jumping || e.player.jump.falling) {
			// Jumping / Falling
			// var new_z: Float = e.transform.position.z;
			// if (e.player.jump.jumping || e.player.jump.falling) {
				// "gravity"
				// var r = jump(e.player, now - e.player.jump.start);
				// new_z = r.z;
			// }

			// var next_position     = new Vec3(e.transform.position.x, e.transform.position.y, new_z);
			// e.transform.velocity += next_position - e.transform.position;

			// Magnet bullshit
			var magnet = new Vec3(0, 0, -10);
			if (e.player.on_ground) {
				magnet.z *= 0.1;
			}
			// if (!e.player.on_ground || e.player.jump.jumping) {
				// magnet.z = 0;
			// }

			var new_z = e.transform.position.z;

			var radius        = e.player.radius;
			var visual_offset = new Vec3(0, 0, radius.z); // player position at feet but ellipsoid position at its centre!
			var diff          = e.transform.position - e.transform.as_absolute();
			var gravity       = new Vec3(0, 0, new_z - e.transform.position.z);
			var packet        = CollisionPacket.from_entity(
				e.transform.as_absolute() + visual_offset,
				e.transform.velocity * dt,
				radius
			);

			Profiler.push_block("player collision", SegmentColor.Player);
			Response.update(packet, gravity + magnet * dt);
			Profiler.pop_block();

			e.transform.position = packet.r3_position - visual_offset + diff;
			e.transform.velocity = packet.r3_velocity / dt; // reverse the dt, so movement doesn't factor it twice
			e.player.on_ground   = packet.grounded;
		}

		// Connected to a rail
		if (e.player.rail != null) {
			friction = e.player.rail.friction;
			e.player.on_ground = true;
		}

		var cd = 1;
		if (GameInput.pressed(Action.TrickA) && e.player.trick_cooldown == 0) {
			 e.player.trick_cooldown = cd;

			if (!e.player.on_ground) {
				Signal.emit("animation-air-trick-a", { e:e });
			} else {
				Signal.emit("animation-rail-trick-a", { e:e });
			}
		}

		if (GameInput.pressed(Action.TrickB) && e.player.trick_cooldown == 0) {
			e.player.trick_cooldown = cd;

			if (!e.player.on_ground) {
				Signal.emit("animation-air-trick-b", { e:e });
			} else {
				Signal.emit("animation-rail-trick-b", { e:e });
			}
		}

		// Not in air
		if (e.player.on_ground) {
			e.player.jump.jumping = false;
			e.player.jump.falling = false;
		}

		e.transform.velocity *= (1 - friction * dt);

		if (e.player.on_ground && ml == 0 && e.transform.velocity.length() < 0.1) {
			e.transform.velocity *= 0;
			e.transform.position = old_position;
		}

		var ppos = e.transform.as_absolute();
		var player_capsule = new Capsule(ppos, ppos, e.player.rail_attach_radius);
		Debug.capsule(player_capsule, 1, 0, 0);

		// Rail Collision
		if ((e.player.rail == null) && (!e.player.on_ground)) {
			RailsHelper.scan_for_rail(e, RailsHelper.get_tile_rails(e)); // need more data here?
			if (e.player.rail != null) {
				e.player.on_ground = true;
				e.player.jump.jumping = false;
				e.player.jump.falling = false;
				e.transform.update();
			}
		}
		else if (e.player.rail != null) {
			// if we're already on the rail, now we need to be sure that:
			//  1. the player is actually still on the rail.
			//  2. the player has not reached the end of a rails segments.

			var cap_result = Intersect.capsule_capsule(player_capsule, e.player.rail.capsule);

			// make sure we haven't gone off the rails!
			var result = RailsHelper.closest_end_of_rail(e.transform.as_absolute(), e.player.rail);
			var rail_direction = result.far - result.near;
			rail_direction.normalize();

			var direction = result.near - e.transform.as_absolute();
			direction.normalize();

			if (Vec3.dot(rail_direction, direction) > 0) {
				cap_result = null;
			}

			var transfer = false;
			if (cap_result == null) {
				transfer = RailsHelper.transfer_rail(e, e.player.rail);
			}

			if ((cap_result == null) && (!transfer)) {
				e.player.rail = null;
			}

			if (e.transform.velocity.length() < e.player.rail_stick_min) {
				e.player.rail = null;
			}
		}

		adjust_camera(e);
	}
}

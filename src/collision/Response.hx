package collision;

import math.Vec3;
import math.Plane;
import math.Utils;
import math.Triangle;

class Response {
	static var VERY_CLOSE_DIST: Float = 0.0005;

	static function collide_with_world(packet: CollisionPacket, e_position: Vec3, e_velocity: Vec3, slide_threshold: Float) {
		if (packet.depth > 5) {
			return e_position;
		}

		// setup
		packet.e_velocity = e_velocity;
		packet.e_norm_velocity = e_velocity.copy();
		packet.e_norm_velocity.normalize();
		packet.e_base_point = e_position;
		packet.e_base_point += e_velocity * VERY_CLOSE_DIST; // exezin fix


		packet.found_collision  = false;
		packet.nearest_distance = 1e20;

		// check for collision
		// NB: scale the octree query by velocity to make sure we still get the
		// triangles we need at high velocities. without this, long falls will
		// jam you into the floor. A bit (25%) of padding is added so I can
		// sleep at night.
		//
		// TODO: can this be cached? max velocity will never increase, so
		// it seems like it'd be safe to query the max size only once, before
		// hitting this function at all.
		var scale = Utils.max(1.5, e_velocity.length()) * 1.25;

		var r3_position = e_position * packet.e_radius;
		var query_radius = packet.e_radius * scale;
		var min = r3_position - query_radius;
		var max = r3_position + query_radius;
		var tris = World.get_triangles(min, max);
		check_collision(packet, tris);

		// no collision
		if (!packet.found_collision) {
			return e_position + e_velocity;
		}

		// collision, now we have to actually do work...
		var dest_point     = e_position + e_velocity;
		var new_base_point = e_position;

		// only update if we are very close
		// or move very close
		if (packet.nearest_distance >= VERY_CLOSE_DIST) {
			var v = e_velocity.copy();
			v.trim(packet.nearest_distance - VERY_CLOSE_DIST);
			new_base_point = packet.e_base_point + v;
			v.normalize();
			packet.intersect_point -= v * VERY_CLOSE_DIST;
		}

		// determine sliding plane
		var slide_plane_origin = packet.intersect_point.copy();
		var slide_plane_normal = new_base_point - packet.intersect_point;
		slide_plane_normal.normalize();

		var sliding_plane = new Plane(slide_plane_origin, slide_plane_normal);
		var slide_factor = sliding_plane.signed_distance(dest_point);

		var new_dest_point = dest_point - slide_plane_normal * slide_factor;

		// new velocity for next iteration
		var new_velocity = new_dest_point - packet.intersect_point;

		// dont recurse if velocity is tiny
		if (new_velocity.length() < VERY_CLOSE_DIST) {
			return new_base_point;
		}

		packet.depth += 1;

		// down the rabbit hole we go
		return collide_with_world(packet, new_base_point, new_velocity, slide_threshold);
	}

	static function check_collision(packet: CollisionPacket, tris: Array<Triangle>) {
		for (tri in tris) {
			Collision.check_triangle(
				packet,
				tri.v0 / packet.e_radius,
				tri.v1 / packet.e_radius,
				tri.v2 / packet.e_radius
			);
		}
	}

	static function collide_and_slide(packet: CollisionPacket, gravity: Vec3) {
		var player_position = packet.r3_position.copy();

		// convert to e-space
		var e_position = packet.r3_position / packet.e_radius;
		var e_velocity = packet.r3_velocity / packet.e_radius;
		var final_position = new Vec3();

		// e_velocity.z = Utils.max(0.0, e_velocity.z);

		var slide_threshold = 0.9;

		// do velocity iteration
		packet.depth = 0;
		final_position = collide_with_world(packet, e_position, e_velocity, slide_threshold);

		// convert back to r3 space
		packet.r3_position = final_position * packet.e_radius;
		packet.r3_velocity = gravity.copy();
		e_velocity += gravity / packet.e_radius;

		// convert velocity to e-space

		// do gravity iteration
		packet.depth = 0;
		final_position = collide_with_world(packet, final_position, e_velocity, slide_threshold);

		// add our sliding direction to the velocity
		// causing a smooth ice-skating sort of effect on angled surfaces
		packet.r3_velocity = packet.r3_position - player_position;
		packet.r3_position = final_position * packet.e_radius;
	}

	static function check_grounded(packet: CollisionPacket) {
		if (packet.found_collision) {
			var e_position = packet.r3_position / packet.e_radius;
			var new_base_point = e_position.copy();

			// get the slope angle
			var slide_plane_normal = new_base_point - packet.intersect_point;
			slide_plane_normal.normalize();
			var slope = Vec3.dot(slide_plane_normal, Vec3.up());

			if (slope > 0.9) {
				// if the intersect point is closer than the very close dist we are
				// stuck inside the floor, so pop us out
				var temp = e_position - packet.intersect_point;
				temp.z -= packet.e_radius.z;
				if (temp.z < VERY_CLOSE_DIST) {
					var push = 0.1;
					packet.r3_position.z = (packet.intersect_point.z + push + packet.e_radius.z) * packet.e_radius.z;
				}
				packet.grounded = true;
			}
		}
	}

	public static function update(packet: CollisionPacket, gravity: Vec3) {
		collide_and_slide(packet, gravity);
		check_grounded(packet);
	}
}

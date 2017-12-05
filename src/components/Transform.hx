package components;

import math.Vec3;
import math.Quat;
import math.Mat4;
import math.Utils;

@:publicFields
class Transform {
	var position: Vec3;
	var velocity: Vec3;
	var orientation: Quat;
	var scale: Vec3;
	var snap_to: Quat;
	var snap: Bool;
	var slerp: Float;
	var accel: Vec3;
	var mtx: Mat4 = new Mat4();
	var tile_x: Int;
	var tile_y: Int;
	var is_static: Bool;

	public var vtile: World.VirtualTile;

	function new(pos: Vec3, ?vel: Vec3, ?rot: Quat, ?sca: Vec3, _static: Bool = false) {
		this.tile_x = 0;
		this.tile_y = 0;
		this.position = pos;
		this.is_static = _static;
		this.recenter();

		if (vel != null) {
			this.velocity = vel;
		}
		else {
			this.velocity = new Vec3(0, 0, 0);
		}

		if (rot != null) {
			this.orientation = rot;
		}
		else {
			this.orientation = new Quat(0, 0, 0, 1);
		}

		if (sca != null) {
			this.scale = sca;
		}
		else {
			this.scale = new Vec3(1, 1, 1);
		}

		this.snap_to = new Quat(0, 0, 0, 1);
		this.snap = false;
		this.slerp = 0;
	}

	private function recenter() {
		if (position.x < 0) { tile_x -= 1; }
		if (position.y < 0) { tile_y -= 1; }
		if (position.x > World.tile_size) { tile_x += 1; }
		if (position.y > World.tile_size) { tile_y += 1; }
		tile_x = Std.int(Utils.wrap(tile_x, World.tiles_x));
		tile_y = Std.int(Utils.wrap(tile_y, World.tiles_y));
		position.x = Utils.wrap(position.x, World.tile_size);
		position.y = Utils.wrap(position.y, World.tile_size);
	}

	inline function as_absolute(): Vec3 {
		return World.to_world(position, tile_x, tile_y);
	}

	function copy() {
		var t = new Transform(
			position.copy(),
			velocity.copy(),
			orientation.copy(),
			scale.copy()
		);
		t.tile_x = tile_x;
		t.tile_y = tile_y;
		t.update();
		return t;
	}

	function update() {
		recenter();

		// mtx = Mat4.from_srt(as_absolute(), orientation.to_euler(), scale);
		// return;
		mtx.identity();
		if (scale.lengthsq() > 0) {
			mtx *= Mat4.scale(scale);
		}
		mtx *= Mat4.rotate(orientation);
		mtx *= Mat4.translate(as_absolute());
	}
}

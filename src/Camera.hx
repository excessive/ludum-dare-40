import math.Vec3;
import math.Quat;
import math.Mat4;
import math.Utils;
import math.Bounds;
import math.Triangle;

import love.graphics.GraphicsModule as Lg;

class Camera {
	public var fov: Float = 80;
	public var orbit_offset = new Vec3(0, -1.75, 0);
	public var offset = new Vec3(0, 0, -4);
	public var position = new Vec3(0, 0, 0);
	public var orientation = new Quat(0, 0, 0, 1);
	public var direction = new Vec3(0, 1, 0);
	public var view: Mat4 = new Mat4();
	public var projection: Mat4 = new Mat4();
	public var clip_distance: Float = 999;
	public var near: Float = 1.0;
	public var far: Float = 300.0;
	public var viewable: Triangle;
	var clip_minimum: Float = 4;
	var clip_bias: Float    = 3;

	var up = Vec3.unit_z();
	var mouse_sensitivity: Float = 0.2;
	var pitch_limit_up: Float = 0.9;
	var pitch_limit_down: Float = 0.9;

	public function new(position: Vec3) {
		this.position  = position;
		this.direction = this.orientation.apply_forward();
	}

	public function rotate_xy(mx: Float, my: Float) {
		var sensitivity = this.mouse_sensitivity;
		var mouse_direction = {
			x: Utils.rad(-mx * sensitivity),
			y: Utils.rad(-my * sensitivity)
		};

		// get the axis to rotate around the x-axis.
		var axis = Vec3.cross(this.direction, this.up);
		axis.normalize();

		// First, we apply a left/right rotation.
		this.orientation = Quat.from_angle_axis(mouse_direction.x, this.up) * this.orientation;

		// Next, we apply up/down rotation.
		// up/down rotation is applied after any other rotation (so that other rotations are not affected by it),
		// hence we post-multiply it.
		var new_orientation = this.orientation * Quat.from_angle_axis(mouse_direction.y, Vec3.unit_x());
		var new_pitch       = Vec3.dot(new_orientation * Vec3.unit_y(), this.up);

		// Don't rotate up/down more than this.pitch_limit.
		// We need to limit pitch, but the only reliable way we're going to get away with this is if we
		// calculate the new orientation twice. If the new rotation is going to be over the threshold and
		// Y will send you out any further, cancel it out. This prevents the camera locking up at +/-PITCH_LIMIT
		if (new_pitch >= this.pitch_limit_up) {
			mouse_direction.y = Math.min(0, mouse_direction.y);
		}
		else if (new_pitch <= -this.pitch_limit_down) {
			mouse_direction.y = Math.max(0, mouse_direction.y);
		}

		this.orientation = this.orientation * Quat.from_angle_axis(mouse_direction.y, Vec3.unit_x());

		// Apply rotation to camera direction
		this.direction = this.orientation.apply_forward();
	}

	function frustum_triangle(w: Float, h: Float) {
		var aspect = Math.max(w / h, h / w);
		var aspect_inv = Math.min(w / h, h / w);
		var fovy = Utils.rad(this.fov * aspect_inv);

		var hheight = Math.tan(fovy/2);
		var hwidth: Float = hheight * aspect;
		var cam_right = Vec3.cross(this.direction, this.up);

		var far_clip = this.far;
		var adjusted = this.position;
		var far_center = adjusted + this.direction * far_clip;
		var far_right  = cam_right * hwidth * far_clip;
		var far_top    = this.up * hheight * far_clip;

		var fbl = far_center - far_right - far_top;
		var ftl = far_center - far_right + far_top;

		var fbr = far_center + far_right - far_top;
		var ftr = far_center + far_right + far_top;

		var use_top = Vec3.distance(adjusted, ftl) > Vec3.distance(adjusted, fbl);

		return new Triangle(
			use_top? ftr : fbr,
			use_top? ftl : fbl,
			// far_center  + far_right  - far_top,
			// far_center  - far_right  - far_top,
			adjusted,
			new Vec3(0, 0, 0)
		);
	}

	static var canvas: love.graphics.Canvas = null;

	public function update(w: Float, h: Float) {
		var aspect = Math.max(w / h, h / w);
		var aspect_inv = Math.min(w / h, h / w);
		var target = this.position + this.direction;

		var orbit = Mat4.translate(this.orbit_offset);
		this.view = Mat4.look_at(this.position, target, Vec3.unit_z()) * orbit;

		var clip = -(Math.max(this.clip_distance, this.clip_minimum) - this.clip_bias);
		clip = Math.max(this.offset.z, clip);
		this.view *= Mat4.translate(new Vec3(this.offset.x, this.offset.y, clip));

		var fovy = this.fov * aspect_inv;
		this.projection = Mat4.from_perspective(fovy, aspect, this.near, this.far);
		this.viewable = frustum_triangle(w, h);

		var vp = this.view * this.projection;
		World.update_visible(this.viewable, vp.to_frustum());

		return;

		#if imgui
		if (canvas == null) {
			canvas = love.graphics.GraphicsModule.newCanvas(512, 384);
		}

		canvas.renderTo(function() {
			var base = this.viewable;
			var tri = new Triangle(
				base.v0 / World.tile_size,
				base.v1 / World.tile_size,
				base.v2 / World.tile_size,
				base.vn
			);

			Lg.clear(0, 0, 0, 255);
			Lg.setBlendMode(Alpha, Alphamultiply);
			Lg.push();
			var wh = canvas.getDimensions();
			Lg.scale(wh.width/(this.far*2), wh.height/(this.far*2));
			Lg.translate(this.far, this.far);
			Lg.scale(World.tile_size / 1.5);
			Lg.setColor(0, 255, 0, 50);
			Lg.polygon(Fill, tri.v0.x, tri.v0.y, tri.v1.x, tri.v1.y, tri.v2.x, tri.v2.y);
			Lg.setColor(255, 0, 0, 127);
			var tile_pos = this.position / World.tile_size;
			Lg.rectangle(Fill, tile_pos.x-0.5, tile_pos.y-0.5, 1, 1);
			Lg.setColor(255, 255, 255, 127);
			for (tile in World.visible_tiles) {
				Lg.rectangle(Fill, tile.x-0.5, tile.y-0.5, 1, 1);
			}
			Lg.pop();

			Lg.setBlendMode(Alpha, Alphamultiply);
			Lg.setColor(255, 255, 255, 255);
		});
		imgui.Widget.image(canvas, 512, 384, 0, 1, 1, 0);
		#end
	}
}

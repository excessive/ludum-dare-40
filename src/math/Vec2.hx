package math;

import haxe.ds.Vector;

abstract Vec2(Vector<Float>) {
	public var x(get, set): Float;
	public var y(get, set): Float;

	public inline function set_x(v: Float) {
		this[0] = v;
		return v;
	}
	public inline function set_y(v: Float) {
		this[1] = v;
		return v;
	}

	public inline function get_x() return this[0];
	public inline function get_y() return this[1];

	public inline function new(x: Float = 0, y: Float = 0) {
		this = new Vector<Float>(2);

		this[0] = x;
		this[1] = y;
	}

	@:arrayAccess
	public inline function get(k: Int) {
		return this[k];
	}

	@:arrayAccess
	public inline function set(k: Int, v: Float) {
		this[k] = v;
		return v;
	}

	public inline function copy() {
		var self: Vec2 = cast this;
		return new Vec2(self.x, self.y);
	}

	@:op(A + B)
	public function add(b: Vec2) {
		var a: Vec2 = cast this;
		return new Vec2(a.x + b.x, a.y + b.y);
	}

	@:op(A - B)
	public function sub(b: Vec2) {
		var a: Vec2 = cast this;
		return new Vec2(a.x - b.x, a.y - b.y);
	}

	@:op(A * B)
	public function scale(b: Float) {
		return new Vec2(this[0] * b, this[1] * b);
	}

	public function length() {
		return Math.sqrt(this[0] * this[0] + this[1] * this[1]);
	}

	public function normalize() {
		var l = this[0] * this[0] + this[1] * this[1];
		if (l == 0) {
			return;
		}
		l = Math.sqrt(l);
		this[0] /= l;
		this[1] /= l;
	}

	public function angle_to(?other: Vec2) {
		if (other != null) {
			return Math.atan2(this[1] - other[1], this[0] - other[0]);
		}
		return Math.atan2(this[1], this[0]);
	}
}

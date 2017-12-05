package math;

class Triangle {
	public var v0: Vec3;
	public var v1: Vec3;
	public var v2: Vec3;
	public var vn: Vec3;

	public inline function new(a, b, c, n) {
		v0 = a;
		v1 = b;
		v2 = c;
		vn = n;
	}

	public inline function min() {
		var min = v0.copy();
		min[0] = Utils.min(min[0], v1[0]);
		min[0] = Utils.min(min[0], v2[0]);
		min[1] = Utils.min(min[1], v1[1]);
		min[1] = Utils.min(min[1], v2[1]);
		min[2] = Utils.min(min[2], v1[2]);
		min[2] = Utils.min(min[2], v2[2]);
		return min;
	}

	public inline function max() {
		var max = v0.copy();
		max[0] = Utils.max(max[0], v1[0]);
		max[0] = Utils.max(max[0], v2[0]);
		max[1] = Utils.max(max[1], v1[1]);
		max[1] = Utils.max(max[1], v2[1]);
		max[2] = Utils.max(max[2], v1[2]);
		max[2] = Utils.max(max[2], v2[2]);
		return max;
	}

	public function normal(): Vec3 {
		var ba = this.v1 - this.v0;
		var ca = this.v2 - this.v0;
		var n = Vec3.cross(ba, ca);
		n.normalize();
		return n;
	}
}

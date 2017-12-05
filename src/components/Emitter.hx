package components;

import love.math.MathModule.random as rand;
import math.Vec3;

@:publicFields
class InstanceData {
	var despawn_time: Float;
	var position: Vec3;
	var velocity: Vec3;

	inline function new(pos: Vec3, vel: Vec3, despawn: Float, radius: Float, spread: Float) {
		this.despawn_time = despawn;
		this.position     = pos + new Vec3(
			(2*rand()-1)*radius,
			(2*rand()-1)*radius,
			0
		);
		this.velocity     = new Vec3(
			vel.x + (2 * rand()-1) * spread,
			vel.y + (2 * rand()-1) * spread,
			vel.z + (2 * rand()-1) * spread
		);
	}
}

typedef BucketData = Array<{
	var position: Vec3;
	var index: Int;
}>;

@:publicFields
class ParticleData {
	static var bucket_size: Int = 16;
	static var map_size: Int = 1024;

	var last_spawn_time: Float = 0.0;
	var particles: Array<InstanceData> = [];
	var buckets = new Array<BucketData>();
	// var current_count: Int = 0;
	var index: Int = 0;
	// var mesh;

	inline function new() {}
	inline function hash(pos: Vec3): Int {
		var bx: Int = Math.floor(pos.x / bucket_size);
		var by: Int = Math.floor(pos.y / bucket_size);
		return bx + by * map_size;
	}
}

typedef Emitter = {
	@:optional var user_data: Dynamic;
	var batch: love.graphics.SpriteBatch;
	var data: ParticleData;
	var lifetime: { min: Float, max: Float };
	var limit: Int;
	var pulse: Float;
	var spawn_radius: Float;
	var spawn_rate: Int;
	var spread: Float;
	var velocity: Vec3;
	var update: Null<Emitter->Int->Void>;
}

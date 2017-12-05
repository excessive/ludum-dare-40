package systems;

import math.Capsule;
import math.Intersect;
import math.Vec3;

class ParticleCollision extends System {
	override public function filter(e: Entity): Bool {
		return e.emitter != null;
	}

	override public function update(entities: Array<Entity>, dt: Float) {
		for (entity in entities) {
			if (entity.player == null) { continue; }

			for (other in entities) {
				if (other == entity) { continue; }

				// we only care about emitters with update functions, since those are
				// the ones used for battle (not effects)
				if (other.emitter.update == null) {
					continue;
				}

				// Player's bullets hit an enemy
				for (cap in entity.capsules.hit) {
					hit(entity, other, cap.final);
				}

				// Enemy's bullets hit a player
				for (cap in other.capsules.hit) {
					hit(other, entity, cap.final);
				}
			}
		}
	}

	private function hit(a: Entity, b: Entity, acap: Capsule) {
		var pd     = b.emitter.data;
		var bucket = pd.buckets[pd.hash(acap.a)];

		// Remove a bullet if it collides
		var i    = bucket.length;
		var bcap = new Capsule(new Vec3(), new Vec3(), 0);
		while (--i >= 0) {
			var bullet = bucket[i];
			bcap.a      = bullet.position;
			bcap.b      = bullet.position;
			bcap.radius = 0.25;

			var ret = Intersect.capsule_capsule(acap, bcap);

			if (ret != null) {
				pd.particles.splice(bullet.index, 1);

				// if (b.combat.iframes == 0) {
				// 	Signal.emit("damage", a, b, ret.p1, (ret.p2 - ret.p1).normalize());
				// }
			}
		}
	}
}

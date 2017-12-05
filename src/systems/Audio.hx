package systems;

import love.audio.AudioModule as La;

class Audio extends System {
	var player: Null<Entity>;

	override function filter(entity: Entity): Bool {
		if (entity.player != null) {
			this.player = entity;
		}
		return entity.sound != null;
	}

	override function update(entities: Array<Entity>, dt: Float) {
		if (player == null) {
			La.setPosition(0, 0, 0);
			La.setVelocity(0, 0, 0);
			La.setDistanceModel(love.audio.DistanceModel.None);
			return;
		}

		var vel = player.transform.velocity;
		var pos = player.transform.as_absolute();
		La.setDistanceModel(Inverse);
		La.setPosition(pos.x, pos.y, pos.z);
		La.setVelocity(vel.x, vel.y, vel.z);

		for (e in entities) {
			var tx = e.transform;
			var loaded = e.sound.loaded;
			var epos = tx.as_absolute();
			var evel = tx.velocity;
			for (source in loaded) {
				source.setPosition(epos.x, epos.y, epos.z);
				source.setVelocity(evel.x, evel.y, evel.z);
			}
		}
	}
}

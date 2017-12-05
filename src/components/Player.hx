package components;

//import ui.*;
import anim9.Anim9;
import anim9.Anim9.Anim9Track;

import editor.Editor;

import components.Drawable;
import components.Rail;

// used by spawn
import math.Vec3;
import components.Transform;

import haxe.Json;
import love.filesystem.FilesystemModule as Fs;

typedef Jump = {
	var jumping:  Bool;
	var falling:  Bool;
	var start:    Float;
	var z_offset: Float;
	var speed:    Float;
}

enum TrickState {
	None;
	TrickA;
	TrickB;
	TrickC;
}

class Player extends System {
	public var rail_stick_min: Float  = 1;
	public var speed:       Float     = 4;
	public var turn_weight: Float     = 3;
	public var mass:        Float     = 75;
	public var friction:    Float     = 1.25;
	public var on_ground:   Bool      = false;
	public var accel:       Vec3      = new Vec3();
	public var radius:      Vec3      = new Vec3(0.25, 0.25, 0.5);
	public var rail_attach_radius: Float = 0.25;
	public var rail:        Rail;
	public var trick_state: TrickState = TrickState.None;
	public var trick_cooldown: Float   = 0;

	public var tracks = new Map<String, Anim9Track>();

	public var jump: Jump = {
		jumping:  false,
		falling:  false,
		start:    0,
		z_offset: 0,
		speed:    0
	};

	function mk_track(tl: Anim9, name: String): Null<Anim9Track> {
		if (this.tracks.exists(name)) {
			return this.tracks[name];
		}
		var track: Anim9Track = tl.new_track(name);

		if (track != null) {
			this.tracks[name] = track;
		}

		return track;
	}

	public function get_track(tl: Anim9, name: String): Anim9Track {
		var track = mk_track(tl, name);
		if (track != null) {
			return track;
		}
		else {
			Log.write(Log.Level.System, "Animation not found: " + name);
			return mk_track(tl, "skate");
		}
	}

	public function load() {
		var saved = Fs.read("game.save", null);
		if (saved.contents != null) {
			// var data: PlayerSave = Json.parse(saved.contents);
		}
	}

	public function save() {
		var data = {};
		var out = Json.stringify(data);
		Fs.write("game.save", out);
	}

	override public function filter(e: Entity) {
		if (e.player != null) {
			return true;
		}
		return false;
	}

	public static function spawn(at: Vec3, player: Player) {
		World.add({
			// attachments: [
			// 	{
			// 		filename: "assets/models/weapons/sword-of-swordening.iqm",
			// 		mesh: null,
			// 		bone: "weapon",
			// 		offset: new Vec3(0, 0, 0.0)
			// 	},
			// 	{
			// 		filename: "assets/models/old/cat.iqm",
			// 		mesh: null,
			// 		bone: "head",
			// 		offset: new Vec3(0, 0, 0.1)
			// 	}
			// ],
			camera: new Camera(at),
			player: player,
			transform: new Transform(at),
			drawable: new Drawable("assets/models/new-player.iqm"),
			animation: {
				filename: "assets/models/new-player.iqm",
				anims: [
					"assets/models/new-player.iqm"
				],
				timeline: null
			}
		});
	}

	override public function process(e: Entity, dt: Float) {
		e.player.trick_cooldown -= dt;
		if (e.player.trick_cooldown < 0) {
			e.player.trick_cooldown = 0;
		}

		if (e.transform.position.z < World.kill_z && false) {
			World.remove(e);
			Main.respawn();
		} else {
			Editor.cursor = e.transform.copy();
		}
	}
}

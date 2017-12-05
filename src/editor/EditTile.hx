package editor;

import imgui.Widget;
import World.WorldTile;

import math.Vec3;

class EditTile {
	public static function draw(tile: WorldTile) {
		var zones = Zone.get_zones();
		var zone_paths = [];
		var i = 0;
		var selected = 0;
		for (tiles in zones) {
			var file = tiles[0].filename;
			if (file == tile.filename) {
				selected = i+1;
			}
			zone_paths.push(file);
			i++;
		}
		tile.filename = zone_paths[selected-1];

		var zone = zones[tile.filename];
		for (tile in zone) {
			Debug.aabb(
				World.to_world(new Vec3(0, 0, -HeightmapTerrain.HEIGHT_SCALE), tile.x, tile.y),
				World.to_world(new Vec3(World.tile_size, World.tile_size, 0), tile.x, tile.y),
				0.25, 0, 1
			);
		}

		var new_name = Widget.input_text("Filename", tile.filename);
		if (new_name != tile.filename) {
			for (tile in zone) {
				tile.filename = new_name;
			}
		}

		selected = Widget.combo("Zone", selected, zone_paths);

		Widget.input_int2("Location", tile.x, tile.y);
	}
}

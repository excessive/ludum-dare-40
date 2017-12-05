package editor;

import math.Vec3;
import math.Quat;
import math.Utils;
import components.Transform;
import components.Drawable;
import components.Drawable.CollisionType;
import components.Rail;
import ui.Helpers;

import Entity.Locator;

#if imgui
import imgui.Widget;
import imgui.Window;
import imgui.MenuBar;

import Main.WindowType;
import editor.Panel.UIPanelCategory;
import editor.Panel.register_panel;
#end

class Editor {
	public static var cursor: Transform;
	public static var current_locator: Null<Entity> = null;
	public static var selected: Null<Entity> = null;
	public static var running: Bool = true;

	static var show_select_drawable = false;
	static var selected_item: String = "";

	public static function init() {
		cursor = new Transform(new Vec3());

		EntityList.init();

#if imgui
		var cats = UIPanelCategory.createAll();
		for (v in cats) {
			Panel.panels.push({
				type: v,
				panels: [],
				dock_at: v == UIPanelCategory.Selection? "Bottom" : null
			});
		}
#end
	}

#if imgui

	static function edit_transform(e: Entity) {
		if (e.transform != null) {
			var pos = e.transform.as_absolute();
			Debug.axis(pos, Vec3.right(), Vec3.forward(), Vec3.up(), 1.0);

			if (Widget.tree_node("Transform", true)) {
				Helpers.drag_vec3("Position", e.transform.position);
				Helpers.drag_vec3("Velocity", e.transform.velocity);
				Helpers.input_quat("Rotation", e.transform.orientation);
				var r1 = Widget.slider_int("TX", e.transform.tile_x, 0, World.tiles_x-1);
				e.transform.tile_x = r1.i1;
				r1 = Widget.slider_int("TY", e.transform.tile_y, 0, World.tiles_y-1);
				e.transform.tile_y = r1.i1;
				if (Widget.button("Randomize##randrot")) {
					var q = new Quat(Math.random()*2-1, Math.random()*2-1, Math.random()*2-1, Math.random()*2-1+0.0001);
					q.normalize();
					e.transform.orientation = q;
				}

				if (e.player != null && e.player.jump.falling) {
					e.player.jump.z_offset = e.transform.position.z;
				}

				// if we've got rails and the transform updates, we need to reapply world xform
				if (e.rails != null) {
					// inverse of old transform to perform undo
					var inv = e.transform.mtx.copy();
					inv.invert();

					e.transform.update();

					// now reapply with updated xform
					var mtx = e.transform.mtx;
					for (rail in e.rails) {
						var start = inv * rail.capsule.a;
						var end = inv * rail.capsule.b;
						rail.capsule.a = mtx * start;
						rail.capsule.b = mtx * end;
					}
				}
				else {
					e.transform.update();
				}

				Helpers.drag_vec3("Scale", e.transform.scale);
				Widget.tree_pop();
			}
		}
		else {
			if (Widget.button("Add transform")) {
				e.transform = cursor.copy();
			}
		}
	}

	static function is_locator(e: Entity) {
		return e.parent != null
			&& e.parent.entity == null
			&& e.parent.name != null
			&& e.parent.entity.transform != null
		;
	}

	static function locator_info(e: Entity) {
		edit_transform(e);
	}

	static function entity_info(e: Entity) {
		var title = Prefab.is_empty()? "New Prefab" : "Add to Prefab";
		if (Widget.button(title)) {
			Prefab.add(e);
		}

		Widget.spacing();

		var size = Window.get_content_region_max();

		edit_transform(e);

		Widget.spacing();

		if (e.drawable != null) {
			if (Widget.tree_node("Drawable", true)) {
				var d = e.drawable;
				Widget.text("Filename");
				Widget.same_line(75);
				Widget.text(d.filename);
				if (Widget.button("Remove##remove_drawable")) {
					e.drawable = null;
				}
				var actor = e.drawable.collision == CollisionType.Triangle;
				if (Widget.checkbox("Collidable##set_collidable", actor)) {
					if (actor) {
						e.drawable.collision = CollisionType.None;
					}
					else {
						e.drawable.collision = CollisionType.Triangle;
					}
				}
				Widget.tree_pop();
			}
		}
		else {
			if (!show_select_drawable && Widget.button("Add drawable")) {
				show_select_drawable = true;
			}
			if (show_select_drawable) {
				if (Widget.button("Cancel##cancel_select_drawable")) {
					show_select_drawable = false;
				}

				if (Window.begin_child("select model", 400, 300)) {
					for (v in EntityList.available_entities) {
						var is_selected = selected_item == v.filename;
						if (Widget.selectable(v.filename, is_selected, 0, 0)) {
							if (selected_item == v.filename) {
								selected_item = null;
								is_selected = false;
							}
							else {
								selected_item = v.filename;
								is_selected = true;
							}
						}
						if (is_selected) {
							if (Widget.button("Add##load_drawable")) {
								e.drawable = new Drawable(v.filename);
								show_select_drawable = false;
							}
						}
					}
				}
				Window.end_child();
			}
		}

		Widget.spacing();

		if (e.rails != null) {
			var mtx = e.transform.mtx;
			if (Widget.tree_node("Rails", true)) {
				var i = 0;
				var inv = mtx.copy();
				inv.invert();
				for (rail in e.rails) {
					var start = inv * rail.capsule.a;
					var end = inv * rail.capsule.b;
					Helpers.drag_vec3('A##$i', start);
					rail.capsule.a = mtx * start;
					Helpers.drag_vec3('B##$i', end);
					rail.capsule.b = mtx * end;
					Widget.spacing();
					i++;
				}
				Widget.tree_pop();
			}

			if (Widget.button("Add rail")) {
				e.rails.push(new Rail(mtx * new Vec3(), mtx * new Vec3()));
			}
		}
		else {
			if (Widget.button("Add rails")) {
				e.rails = [];
			}
		}

		Widget.spacing();
	}

	static function update_transform(loc: Entity, e: Entity) {
		if (loc != null && is_locator(loc)) {
			// var pos = loc.parent.entity.transform.position;
			// e.transform.position += pos;
		}
	}

	public static function draw() {
		if (!Main.showing_menu(WindowType.EditorUI)) {
			return;
		}

		register_panel(UIPanelCategory.Settings, "Map Data", function() {
			if (Widget.button("Reload Map")) {
				World.reload();
				Main.respawn();
			}
			if (Widget.button("Save Map")) {
				World.save();
			}
			if (Widget.button("Rebuild Octree")) {
				World.rebuild_octree();
			}
		});

		register_panel(UIPanelCategory.Settings, "Playable Area", function() {
			var ret = Widget.slider_float("Kill Z", World.kill_z, -HeightmapTerrain.HEIGHT_SCALE, 0);
			World.kill_z = ret.f1;
		});

		register_panel(UIPanelCategory.Entities, "Add", function() {
			if (Widget.button("New Entity")) {
				var e = {};
				World.add(e);
				selected = e;
			}
		});

		register_panel(UIPanelCategory.Entities, "Prefab", function() {
			Prefab.draw(selected);
		});

		register_panel(UIPanelCategory.Entities, "Current Tile", function() {
			var vt = World.virtual_tile_at(cursor.as_absolute());
			var real = vt.world_tile;
			EditTile.draw(real);

			Widget.spacing();

			if (Widget.tree_node("Entities", true)) {
				var entities = vt.world_tile.entities;
				var i = 0;
				for (e in entities) {
					if (e.drawable != null && e.drawable.filename == Zone.HEIGHTMAP_TILE) {
						continue;
					}
					var label = e.drawable != null? e.drawable.filename : Std.string(e.transform.as_absolute());
					if (Widget.selectable(label + '##$i', e == selected, 0, 0)) {
						if (e == selected) {
							selected = null;
						}
						else {
							selected = e;
						}
					}
					i++;
				}
				Widget.tree_pop();
			}
		});

		register_panel(UIPanelCategory.Selection, "Selected", function() {
			if (selected != null && selected.parent != null) {
				current_locator = selected.parent.entity;
			}

			/*
			if (current_locator != null) {
				locator_info(current_locator);

				if (selected != null) {
					if (Widget.button("Assign to locator")) {
						selected.parent = current_locator.parent;
						update_transform(current_locator, selected);
					}
					if (Widget.button("Remove locator") && selected.parent != null) {
						current_locator = null;
						selected.parent = null;
						update_transform(current_locator, selected);
					}
				}
			}
			*/

			if (selected != null) {
				entity_info(selected);
				Widget.spacing();
				if (Widget.button("Delete", 0, 0)) {
					World.remove(selected);
					selected = null;
				}
			}
			else {
				Widget.text("No entity selected");
			}
		});

		for (panel in Panel.panels) {
			if (panel.panels.length == 0) {
				continue;
			}
			if (panel.dock_at != null) {
				Window.set_next_dock(panel.dock_at);
			}
			if (Window.begin_dock(panel.type.getName())) {
				Widget.begin_group();
				if (panel.panels.length == 0) {
					Widget.text("Nothing to see here.");
				}
				for (info in panel.panels) {
					if (!Widget.tree_node(info.label, true)) {
						continue;
					}
					info.cb();
					Widget.tree_pop();
				}
				Widget.end_group();
			}
			panel.panels = [];
			Window.end_dock();
		}
	}
#else
	public static inline function draw() {}
#end
}

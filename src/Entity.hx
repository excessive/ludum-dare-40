import components.*;

typedef AttachedDrawable = {
	var filename: String;
	var bone:     String;
	var mesh:     Null<iqm.Iqm.IqmFile>;
	var offset:   math.Vec3;
}

typedef Locator = {
	entity: Null<Entity>,
	name: Null<String>
}

typedef Entity = {
	@:optional var attachments: Array<AttachedDrawable>;
	@:optional var animation:   Animation;
	@:optional var camera:      Camera;
	@:optional var drawable:    Drawable;
	@:optional var player:      Player;
	@:optional var transform:   Transform;
	@:optional var trigger:     Trigger;
	@:optional var sound:       Sound;
	@:optional var rails:       Array<Rail>;
	@:optional var prefab_path: String;
	@:optional var parent:      Locator;
}

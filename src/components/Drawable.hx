package components;

import iqm.Iqm.IqmFile;

enum ShaderType {
	Basic;
	Terrain;
}

enum CollisionType {
	None;
	Triangle;
}

@:publicFields
class Drawable {
	var filename: String;
	var mesh: Null<IqmFile> = null;
	var collision: CollisionType;
	var shader: ShaderType;

	function new(model: String, ?collision: CollisionType, ?shader: ShaderType) {
		this.filename  = model;
		this.collision = collision != null ? collision : CollisionType.None;
		this.shader    = shader != null ? shader : ShaderType.Basic;
	}
}

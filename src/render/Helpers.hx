package render;

import love.graphics.Shader;
import love.graphics.GraphicsModule as Lg;

class Helpers {
	public static inline function setColor(r: Float, g: Float, b: Float, a: Float) {
		Lg.setColor(r * 255.0, g * 255.0, b * 255.0, a * 255.0);
	}

	public static inline function send(shader: Shader, name: String, data: Dynamic) {
		var result = shader.getExternVariable(name);
		if (result != null && result.type != null) {
			shader.send(name, data);
		}
	}
}

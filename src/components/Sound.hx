package components;

import love.audio.Source;

class Sound {
	public var sounds = new Map<String, String>();
	public var loaded: Map<String, Source>;
	public function new(sounds_available: Map<String, String>) {
		this.sounds = sounds_available;
	}
}

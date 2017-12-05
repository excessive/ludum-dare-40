package utils;

import utils.Assert.assert;

class CacheResource<T, Options> {
	var storage: Map<String, T>;
	var ignore: Map<String, Bool>;
	var loader: String->Options->T;

	public function new(load_cb: String->Options->T) {
		this.loader = load_cb;
		this.clear();
	}

	public function load(filename: String, options: Options): Null<T> {
		if (this.ignore.exists(filename)) {
			return null;
		}
		if (this.storage.exists(filename)) {
			return this.storage[filename];
		}
		var res = this.loader(filename, options);
		if (res == null) {
			this.ignore[filename] = true;
			assert(res != null, 'Unable to load resource "$filename"');
			return null;
		}
		this.storage[filename] = res;
		return res;
	}

	public function clear() {
		this.storage = new Map<String, T>();
		this.ignore = new Map<String, Bool>();
	}
}
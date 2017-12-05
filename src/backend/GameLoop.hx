package backend;

#if cpp
typedef NativeGameLoop = backend.cpp.GameLoop;
#elseif lua
typedef NativeGameLoop = backend.love.GameLoop;
#end

abstract GameLoop(NativeGameLoop) {
	public static inline function run() return NativeGameLoop.run();
}

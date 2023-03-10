all:
	docker build -t zig-wasm-audio-framebuffer . && docker run -p8000:8000 -ti --rm zig-wasm-audio-framebuffer


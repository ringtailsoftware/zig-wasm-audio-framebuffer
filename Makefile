all:
	docker build -t zwaf .
	zig build && docker run -p8000:8000 -v ${PWD}/zig-out:/data -w /data --rm zwaf python3 -m http.server 8000

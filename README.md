# zig-wasm-audio

Toby Jaffey https://mastodon.me.uk/@tobyjaffey

Library code and examples of integrating zig and wasm for audio on the web.

There is a mismatch between low-level audio (found in games, editing tools and music generation) and browser based audio. Games tend to produce PCM sample data in real-time, while browsers provide higher level interfaces allowing playback of short clips or simple synthesis based on oscillators.

Using <a href="https://developer.mozilla.org/en-US/docs/Web/API/AudioWorkletNode">AudioWorkletNode</a> it is possible to use raw PCM data directly for playback in browsers. These samples demonstrate doing that.

# Build and test

    zig build
    cd zig-out && python3 -m http.server 8000

Browse to http://localhost:8000

# How does it work?

Each sample consists of a small wasm library which exposes functions to setup and render blocks of sound (called "quantum" in WebAudio). Stereo sound is assumed throughout.

Tell wasm what the output sample rate is (e.g. 44100Hz)

    export fn setSampleRate(s:f32) void

Fetch a pointer to the left or right channel data

    export fn getLeftBufPtr() [*]u8
    export fn getRightBufPtr() [*]u8

Request wasm library renders a single quantum (128 samples) into the left and right channels

    export fn renderSoundQuantum();

The `WasmPcm` (`wasmpcm.js`) class creates an AudioWorkletNode WASMWorkletProcessor using `pcm-processor.js`. At regular intervals `WasmPcm` calls `pcmProcess()` to request audio data from wasm (`renderSoundQuantum()`). This data is written to a shared ringbuffer. In the worklet, the ringbuffer is consumed and samples are written out.

## The ringbuffer

The ringbuffer is used is <a href="https://github.com/padenot/ringbuf.js/">ringbuf.js</a> which provides a "thread-safe wait-free single-consumer single-producer ring buffer" backed by a SharedArrayBuffer.

# Compatibility

Working in Firefox (111.0) and Chrome (110.0.5481.177). Safari does not work - though it sometimes does, perhaps suggesting a race condition. Unnfortunately, Safari fails silently (literally).

# CORS (Cross-Origin Resource Sharing)

To share data between the main thread and the worklet, SharedArrayBuffer is used. This requires two HTTP headers to be set:

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

However, this is worked around by using <a href="https://github.com/gzuidhof/coi-serviceworker">coi-serviceworker</a>


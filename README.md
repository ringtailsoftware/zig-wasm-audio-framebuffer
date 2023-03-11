# zig-wasm-audio-framebuffer

Toby Jaffey https://mastodon.me.uk/@tobyjaffey

Straightforward examples of integrating Zig and Wasm for audio and graphics on the web.

## Aims

 - Cross-platform (running on multiple browsers and operating systems)
 - Simple understandable code. No hidden libraries, no "emscripten magic"
 - Single thread of execution in Zig, one wasm binary per program
 - `while(true) { update(); render() }` style
 - Use existing C libraries to do fun things

# Demos

Visit https://ringtailsoftware.github.io/zig-wasm-audio-framebuffer

 - Sinetone, simple waveform generator
 - Synth, HTML/CSS piano keyboard driving MIDI synth
 - Mod, Pro-Tracker mod player
 - Mandelbrot, mandelbrot set, mouse interaction
 - Bat, arcade style game skeleton, keyboard control, interactive graphics, background music, sound effects
 - Doom, Doom1 Shareware, keyboard control, MIDI music, sound effects
 - TinyGL, software GL renderer in Wasm
 - OliveC, graphics library with sprite blit, circle, rectangle, line, etc.

# Build and test (assumes you have zig installed)

    zig build
    cd zig-out && python3 -m http.server 8000

# Build and test via docker

    make

Browse to http://localhost:8000

## Video system

An in-memory 32bpp ARGB framebuffer is created and controlled in Zig. To render onto a canvas element, JavaScript:

 - Requests the framebuffer Zig/WebAssembly pointer with `getGfxBufPtr()`
 - Wraps the memory in a `Uint8ClampedArray`
 - Creates an `ImageData` from the `Uint8ClampedArray`
 - Shows the `ImageData` in canvas's graphics context

## Audio pipeline

An <a href="https://developer.mozilla.org/en-US/docs/Web/API/AudioWorkletNode">AudioWorkletNode</a> is used to move PCM samples from WebAssembly to the audio output device.

The system is hardcoded to 2 channels (stereo) and uses 32-bit floats for audio data throughout. In-memory arrays of audio data are created and controlled in Zig.

The AudioWorkletNode expects to pull chunks of audio to be rendered on-demand. However, being isolated from the main thread it cannot directly communicate with the main Wasm program. This is solved by using a <a href="https://github.com/padenot/ringbuf.js/">shared ringbuffer</a>. To render audio to the output device, JavaScript:

 - Tells Zig/WebAssembly the expected sample rate in Hz for the output device, `setSampleRate(44100)`
 - Forever, checks if the ringbuffer has space for more data
 - Tells Zig/WebAssembly to fill its audio buffers with `renderSoundQuantum()`
 - Fetches pointers to the left and right channels using `getLeftBufPtr()` `getRightBufPtr()`
 - Copies from left and right channels into the ringbuffer

The `WasmPcm` (`wasmpcm.js`) class creates the `AudioWorkletNode` `WASMWorkletProcessor` using `pcm-processor.js`. At regular intervals `WasmPcm` calls `pcmProcess()` to request audio data from Wasm.

# Compatibility

Tested on Safari/Chrome/Firefox on macOS, Safari on iPhone SE2/iPad, Chrome/Android Galaxy Tablet

# iOS unmute

By default web audio plays under the same rules as the ringer. The `unmute.js` script loops a constant silence in the background to force playback while the mute button is on.

# CORS (Cross-Origin Resource Sharing)

To share data between the main thread and the worklet, SharedArrayBuffer is used. This requires two HTTP headers to be set:

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

However, this is worked around by using <a href="https://github.com/gzuidhof/coi-serviceworker">coi-serviceworker</a> which reloads the page on startup.


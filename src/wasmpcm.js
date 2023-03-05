import { RingBuffer } from "./ringbuf.js";
import { unmute } from "./unmute.js";

const RENDER_QUANTUM_FRAMES = 128;  // web audio's fixed block size
let audioWorklet = null;
let maxQuanta = 100;    // ringbuffer size in audio blocks
let sab = new SharedArrayBuffer((RENDER_QUANTUM_FRAMES*4) * maxQuanta);  // 4 bytes per float
let rb = new RingBuffer(sab, Float32Array);
let globalInstance = null;
let console_buffer = '';
let lastFrameUs = getTimeUs();
var audioContext = null;

function console_write(dataPtr, len) {
    const wasmMemoryArray = new Uint8Array(globalInstance.exports.memory.buffer);
    var arr = new Uint8Array(wasmMemoryArray.buffer, dataPtr, len);
    let string = new TextDecoder().decode(arr);

    console_buffer += string.toString('binary');

    // force output of very long line
    if (console_buffer.length > 1024) {
        console.log(console_buffer);
        console_buffer = '';
    }

    // break on lines
    let lines = console_buffer.split(/\r?\n/);
    if (lines.length > 1) {
        console_buffer = lines.pop();
        lines.forEach(l => console.log(l));
    }
}

function pcmProcess() {
    const wasmMemoryArray = new Uint8Array(globalInstance.exports.memory.buffer);
    const leftBufPtr = globalInstance.exports.getLeftBufPtr();
    const rightBufPtr = globalInstance.exports.getRightBufPtr();

    var leftArray = new Float32Array(wasmMemoryArray.buffer, leftBufPtr, RENDER_QUANTUM_FRAMES);
    var rightArray = new Float32Array(wasmMemoryArray.buffer, rightBufPtr, RENDER_QUANTUM_FRAMES);

    if (audioWorklet != null) {
        const quanta = Math.floor(rb.availableWrite() / (RENDER_QUANTUM_FRAMES*2));
        //console.log("quanta", quanta, "avwr", rb.availableWrite());

        for (var n=0;n<quanta;n++) {
            globalInstance.exports.renderSoundQuantum();
            if (RENDER_QUANTUM_FRAMES != rb.push(leftArray)) {
                console.log("push failed!");
            }
            if (RENDER_QUANTUM_FRAMES != rb.push(rightArray)) {
                console.log("push failed!");
            }
        }
    }
}

function renderGraphics(canvas) {
    const ctx = canvas.getContext('2d');

    const WIDTH = 320;
    const HEIGHT = 240;

    const wasmMemoryArray = new Uint8Array(globalInstance.exports.memory.buffer);
    const gfxBufPtr = globalInstance.exports.getGfxBufPtr();
    const now = getTimeUs();
    globalInstance.exports.update(now/1000 - lastFrameUs/1000);
    lastFrameUs = now;
    globalInstance.exports.renderGfx();
    var gfxArray = new Uint8ClampedArray(wasmMemoryArray.buffer, gfxBufPtr, WIDTH*HEIGHT*4);
    const imageData = new ImageData(gfxArray, WIDTH, HEIGHT);
    ctx.putImageData(imageData, 0, 0);
}

function getTimeUs() {
    return window.performance.now() * 1000;
}

export class WasmPcm {
    static getInstance() {
        return globalInstance;
    }

    static async init(wasmFile) {
        audioContext = new AudioContext();

        // fetch wasm and instantiate
        await fetch(wasmFile).then((response) => {
            return response.arrayBuffer();
        }).then((bytes) => {
            let imports = {
                env: {
                    console_write: console_write,
                    getTimeUs: getTimeUs
                }
            };
            return WebAssembly.instantiate(bytes, imports);
        }).then((results) => {
            let instance = results.instance;
            globalInstance = instance;
        }).catch((err) => {
            console.log(err);
        });

        
        await audioContext.audioWorklet.addModule('pcm-processor.js');

        unmute(audioContext);
    }

    static async start() {
        // start audio
        const pcmProcessor = new AudioWorkletNode(audioContext, 'pcm-worklet-processor', {
            processorOptions: {sab:sab},
            outputChannelCount: [2] // stereo
        });
        pcmProcessor.connect(audioContext.destination);
        audioWorklet = pcmProcessor;

        // tell wasm to start
        if (globalInstance.exports.init) {
            globalInstance.exports.init();
        }

        if (globalInstance.exports.setSampleRate) {
            globalInstance.exports.setSampleRate(audioContext.sampleRate);
        }

        // attach key handlers
        if (globalInstance.exports.keyevent) {
            document.addEventListener('keydown', (event) => {
                globalInstance.exports.keyevent(event.keyCode, true);
            });
            document.addEventListener('keyup', (event) => {
                globalInstance.exports.keyevent(event.keyCode, false);
            });
        }

        const update = () => {
            // poll sound
            pcmProcess();

            // poll graphics
            let canvasEl = document.getElementById('canvas');
            if (canvasEl) {
                renderGraphics(canvasEl);
            }
            requestAnimationFrame(update);
        };

        requestAnimationFrame(update);

        audioContext.resume();
    }
}

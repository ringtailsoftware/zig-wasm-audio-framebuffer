import { RingBuffer } from "./ringbuf.js";

const RENDER_QUANTUM_FRAMES = 128;  // web audio's fixed block size
let audioWorklet = null;
let maxQuanta = 100;    // ringbuffer size in audio blocks
let sab = new SharedArrayBuffer((RENDER_QUANTUM_FRAMES*4) * maxQuanta);  // 4 bytes per float
let rb = new RingBuffer(sab, Float32Array);
let globalInstance = null;

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

export class WasmPcm {
    static getInstance() {
        return globalInstance;
    }

    static async startAudio(wasmFile, context) {
        await fetch(wasmFile).then((response) => {
            return response.arrayBuffer();
        }).then((bytes) => {
            let imports = {
                env: {
                }
            };
            return WebAssembly.instantiate(bytes, imports);
        }).then((results) => {
            let instance = results.instance;
            globalInstance = instance;
            globalInstance.exports.setSampleRate(context.sampleRate);
        }).catch((err) => {
            console.log(err);
        });

        await context.audioWorklet.addModule('pcm-processor.js');
        const pcmProcessor = new AudioWorkletNode(context, 'pcm-worklet-processor', {
            processorOptions: {sab:sab},
            outputChannelCount: [2] // stereo
        });
        pcmProcessor.connect(context.destination);
        audioWorklet = pcmProcessor;

        setInterval(() => {
            const rd = rb.availableRead();
            const wr = rb.availableWrite();
            const total = maxQuanta * RENDER_QUANTUM_FRAMES;
            //console.log('rd:' + rd + ' wr:' + wr + ' total:' + total);
            pcmProcess();
        }, 50);

        context.resume();
    }
}

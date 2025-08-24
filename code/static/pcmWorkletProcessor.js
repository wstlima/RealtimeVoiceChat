// static/pcmWorkletProcessor.js
class PCMWorkletProcessor extends AudioWorkletProcessor {
  process(inputs) {
    const in32 = inputs[0][0];
    if (in32) {
      // convert Float32 → Int16 in the worklet
      const int16 = new Int16Array(in32.length);
      let sumSq = 0;
      for (let i = 0; i < in32.length; i++) {
        let s = in32[i];
        if (s < -1) s = -1;
        else if (s > 1) s = 1;
        sumSq += s * s;
        int16[i] = s < 0 ? s * 0x8000 : s * 0x7FFF;
      }
      const rms = Math.sqrt(sumSq / in32.length);
      // send raw ArrayBuffer with RMS value
      this.port.postMessage({ pcm: int16.buffer, rms }, [int16.buffer]);
    }
    return true;
  }
}

registerProcessor('pcm-worklet-processor', PCMWorkletProcessor);

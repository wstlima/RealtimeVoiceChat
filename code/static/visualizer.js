(function(){
  class Visualizer {
    constructor(){
      this.analyser = null;
      this.dataArray = null;
      this.scene = null;
      this.camera = null;
      this.renderer = null;
      this.bars = [];
      this.animationId = null;
    }
    start(audioCtx, stream){
      if (this.renderer) return; // already started
      this.analyser = audioCtx.createAnalyser();
      this.analyser.fftSize = 256;
      const source = audioCtx.createMediaStreamSource(stream);
      source.connect(this.analyser);
      this.dataArray = new Uint8Array(this.analyser.frequencyBinCount);

      const canvas = document.getElementById('visualizer');
      const width = canvas.clientWidth;
      const height = canvas.clientHeight;

      this.renderer = new THREE.WebGLRenderer({canvas});
      this.renderer.setSize(width, height);
      this.scene = new THREE.Scene();
      this.camera = new THREE.PerspectiveCamera(75, width/height, 0.1, 1000);
      this.camera.position.z = 5;

      const barCount = this.analyser.frequencyBinCount;
      const spacing = 0.15;
      for(let i=0;i<barCount;i++){
        const geometry = new THREE.BoxGeometry(0.1,0.1,0.1);
        const material = new THREE.MeshBasicMaterial({color:0x00ff00});
        const bar = new THREE.Mesh(geometry, material);
        bar.position.x = (i - barCount/2) * spacing;
        this.scene.add(bar);
        this.bars.push(bar);
      }

      const animate = () => {
        this.analyser.getByteFrequencyData(this.dataArray);
        for(let i=0;i<this.bars.length;i++){
          const scale = (this.dataArray[i]/255)*2 + 0.1;
          this.bars[i].scale.y = scale;
        }
        this.renderer.render(this.scene, this.camera);
        this.animationId = requestAnimationFrame(animate);
      };
      animate();
    }
    stop(){
      if(this.animationId) cancelAnimationFrame(this.animationId);
      if(this.renderer){
        this.renderer.dispose();
        this.renderer = null;
      }
      this.bars = [];
      this.analyser = null;
    }
  }
  window.AudioVisualizer = new Visualizer();
})();

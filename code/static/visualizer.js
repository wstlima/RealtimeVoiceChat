class AudioVisualizer {
  constructor(container, audioContext) {
    this.container = container;
    this.audioContext = audioContext;
    this.analyser = audioContext.createAnalyser();
    this.analyser.fftSize = 64;
    this.dataArray = new Uint8Array(this.analyser.frequencyBinCount);

    const width = container.clientWidth || 300;
    const height = container.clientHeight || 150;
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setSize(width, height);
    container.appendChild(this.renderer.domElement);

    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
    this.camera.position.z = 40;

    const light = new THREE.DirectionalLight(0xffffff, 1);
    light.position.set(0, 1, 1);
    this.scene.add(light);

    this.bars = [];
    const barCount = this.analyser.frequencyBinCount;
    const spacing = 1.5;
    for (let i = 0; i < barCount; i++) {
      const geometry = new THREE.BoxGeometry(1, 1, 1);
      const material = new THREE.MeshStandardMaterial({ color: 0x4CAF50 });
      const bar = new THREE.Mesh(geometry, material);
      bar.position.x = (i - barCount / 2) * spacing;
      this.scene.add(bar);
      this.bars.push(bar);
    }

    this.animate = this.animate.bind(this);
    requestAnimationFrame(this.animate);
  }

  connectSource(source) {
    source.connect(this.analyser);
  }

  animate() {
    requestAnimationFrame(this.animate);
    this.analyser.getByteFrequencyData(this.dataArray);
    for (let i = 0; i < this.bars.length; i++) {
      const scale = this.dataArray[i] / 255;
      this.bars[i].scale.y = Math.max(scale * 10, 0.1);
    }
    this.renderer.render(this.scene, this.camera);
  }
}

window.AudioVisualizer = AudioVisualizer;

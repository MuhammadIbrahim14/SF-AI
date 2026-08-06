/**
 * SIE spike — MediaPipe Hand Landmarker bridge for Flutter Web.
 * Exposes window.sieSpike for Dart js_interop.
 */
import {
  FilesetResolver,
  HandLandmarker,
} from "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.18/+esm";

const MODEL_URL =
  "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task";
const WASM_ROOT =
  "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.18/wasm";

let handLandmarker = null;
let video = null;
let stream = null;
let rafId = 0;
let lastVideoTime = -1;
let onFrame = null;
let startedAt = 0;
let cameraFrames = 0;
let lastCameraTick = 0;
let cameraFps = 0;

function ensurePreviewChrome() {
  let wrap = document.getElementById("sie-spike-preview");
  if (wrap) return wrap;
  wrap = document.createElement("div");
  wrap.id = "sie-spike-preview";
  wrap.style.cssText =
    "position:fixed;right:12px;bottom:12px;width:240px;height:180px;" +
    "z-index:9998;border-radius:12px;overflow:hidden;border:2px solid #22d3ee;" +
    "box-shadow:0 8px 24px rgba(0,0,0,.45);background:#000;pointer-events:none;";
  document.body.appendChild(wrap);
  return wrap;
}

function packLandmarks(result, inferMs) {
  const now = performance.now();
  cameraFrames += 1;
  if (now - lastCameraTick >= 1000) {
    cameraFps = cameraFrames;
    cameraFrames = 0;
    lastCameraTick = now;
  }

  let landmarks = [];
  let confidence = 0;
  let detected = false;
  if (result && result.landmarks && result.landmarks.length > 0) {
    detected = true;
    landmarks = result.landmarks[0].map((p) => ({ x: p.x, y: p.y, z: p.z ?? 0 }));
    if (result.handedness && result.handedness[0] && result.handedness[0][0]) {
      confidence = result.handedness[0][0].score ?? 0.8;
    } else {
      confidence = 0.85;
    }
  }

  return {
    detected,
    confidence,
    landmarks,
    inferMs,
    cameraFps,
    timestampMs: now,
    startupMs: startedAt > 0 ? now - startedAt : 0,
  };
}

async function detectLoop() {
  rafId = requestAnimationFrame(detectLoop);
  if (!handLandmarker || !video || video.readyState < 2) return;
  if (video.currentTime === lastVideoTime) return;
  lastVideoTime = video.currentTime;

  const t0 = performance.now();
  let result;
  try {
    result = handLandmarker.detectForVideo(video, t0);
  } catch (e) {
    console.error("sieSpike detect error", e);
    return;
  }
  const inferMs = performance.now() - t0;
  if (typeof onFrame === "function") {
    onFrame(JSON.stringify(packLandmarks(result, inferMs)));
  }
}

window.sieSpike = {
  async start(callback) {
    onFrame = callback;
    startedAt = performance.now();
    lastCameraTick = startedAt;
    cameraFrames = 0;

    if (!handLandmarker) {
      const vision = await FilesetResolver.forVisionTasks(WASM_ROOT);
      handLandmarker = await HandLandmarker.createFromOptions(vision, {
        baseOptions: {
          modelAssetPath: MODEL_URL,
          delegate: "GPU",
        },
        runningMode: "VIDEO",
        numHands: 1,
        minHandDetectionConfidence: 0.6,
        minHandPresenceConfidence: 0.6,
        minTrackingConfidence: 0.5,
      });
    }

    stream = await navigator.mediaDevices.getUserMedia({
      audio: false,
      video: {
        facingMode: "user",
        width: { ideal: 640 },
        height: { ideal: 480 },
        frameRate: { ideal: 30 },
      },
    });

    video = document.createElement("video");
    video.setAttribute("playsinline", "true");
    video.muted = true;
    video.autoplay = true;
    video.srcObject = stream;
    video.style.cssText = "width:100%;height:100%;object-fit:cover;transform:scaleX(-1);";

    const wrap = ensurePreviewChrome();
    wrap.innerHTML = "";
    wrap.appendChild(video);
    await video.play();

    cancelAnimationFrame(rafId);
    lastVideoTime = -1;
    detectLoop();
    return { ok: true, platform: "web" };
  },

  stop() {
    cancelAnimationFrame(rafId);
    rafId = 0;
    onFrame = null;
    if (stream) {
      stream.getTracks().forEach((t) => t.stop());
      stream = null;
    }
    if (video) {
      video.srcObject = null;
      video.remove();
      video = null;
    }
    const wrap = document.getElementById("sie-spike-preview");
    if (wrap) wrap.remove();
  },
};

console.info("[sieSpike] hand_landmarker_bridge.js loaded");

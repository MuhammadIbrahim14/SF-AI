/**
 * SIE Vision — MediaPipe Hand Landmarker bridge for Flutter Web.
 * Exposes window.sieHandLandmarker for Dart js_interop.
 *
 * Primary path (Chrome): VIDEO mode + getUserMedia (Flutter camera image
 * streams are not reliable on web). IMAGE mode retained for offline buffers.
 *
 * Host must include before Flutter bootstrap:
 *   <script type="module" src="sie_hand_landmarker_bridge.js"></script>
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
let lastDetectMs = 0;
let liveCallback = null;
let frameSequence = 0;
let runningMode = "IMAGE";
/** Cap MediaPipe detect rate to reduce JS↔Dart JSON + CPU lag on Chrome. */
const TARGET_DETECT_FPS = 20;
const MIN_DETECT_INTERVAL_MS = 1000 / TARGET_DETECT_FPS;

function packHands(result, inferMs) {
  const hands = [];
  if (result && result.landmarks) {
    for (let i = 0; i < result.landmarks.length; i++) {
      const lms = result.landmarks[i].map((p) => ({
        x: p.x,
        y: p.y,
        z: p.z ?? 0,
        visibility: p.visibility,
        presence: p.presence,
      }));
      let handedness = "unknown";
      let handednessScore = 0;
      if (result.handedness && result.handedness[i] && result.handedness[i][0]) {
        const h = result.handedness[i][0];
        const name = (h.categoryName || "").toLowerCase();
        handedness = name.includes("left")
          ? "left"
          : name.includes("right")
            ? "right"
            : "unknown";
        handednessScore = h.score ?? 0;
      }
      hands.push({
        landmarks: lms,
        handedness,
        handednessScore,
        handConfidence: handednessScore > 0 ? handednessScore : 0.85,
        index: i,
      });
    }
  }
  return { hands, inferMs, frameSequence: ++frameSequence };
}

function ensurePreview() {
  let wrap = document.getElementById("sie-camera-preview");
  if (wrap) return wrap;
  wrap = document.createElement("div");
  wrap.id = "sie-camera-preview";
  wrap.style.cssText =
    "position:fixed;right:12px;bottom:12px;width:200px;height:150px;" +
    "z-index:9998;border-radius:12px;overflow:hidden;border:2px solid #22d3ee;" +
    "box-shadow:0 8px 24px rgba(0,0,0,.45);background:#000;pointer-events:none;";
  document.body.appendChild(wrap);
  return wrap;
}

function removePreview() {
  const wrap = document.getElementById("sie-camera-preview");
  if (wrap) wrap.remove();
}

async function ensureLandmarker(options, mode) {
  if (handLandmarker && runningMode === mode) return;
  if (handLandmarker) {
    try {
      handLandmarker.close?.();
    } catch (_) {}
    handLandmarker = null;
  }
  const vision = await FilesetResolver.forVisionTasks(WASM_ROOT);
  handLandmarker = await HandLandmarker.createFromOptions(vision, {
    baseOptions: {
      modelAssetPath: MODEL_URL,
      delegate: "GPU",
    },
    runningMode: mode,
    numHands: options?.numHands ?? 1,
    minHandDetectionConfidence: options?.minHandDetectionConfidence ?? 0.55,
    minHandPresenceConfidence: options?.minHandPresenceConfidence ?? 0.55,
    minTrackingConfidence: options?.minTrackingConfidence ?? 0.5,
  });
  runningMode = mode;
}

async function detectLoop() {
  rafId = requestAnimationFrame(detectLoop);
  if (!handLandmarker || !video || video.readyState < 2) return;
  if (video.currentTime === lastVideoTime) return;

  const t0 = performance.now();
  if (t0 - lastDetectMs < MIN_DETECT_INTERVAL_MS) return;
  lastVideoTime = video.currentTime;
  lastDetectMs = t0;

  let result;
  try {
    result = handLandmarker.detectForVideo(video, t0);
  } catch (e) {
    console.error("[sieHandLandmarker] detect error", e);
    return;
  }
  const inferMs = performance.now() - t0;
  if (typeof liveCallback === "function") {
    try {
      liveCallback(JSON.stringify(packHands(result, inferMs)));
    } catch (e) {
      console.error("[sieHandLandmarker] callback error", e);
    }
  }
}

window.sieHandLandmarker = {
  async init(options) {
    // Warm IMAGE mode; live capture switches to VIDEO when started.
    await ensureLandmarker(options || {}, "IMAGE");
    return { ok: true };
  },

  /**
   * Starts getUserMedia + VIDEO HandLandmarker loop (primary Chrome path).
   * @param {function(string): void} callback — JSON landmark payloads
   * @param {object} [options]
   */
  async startLive(callback, options) {
    liveCallback = callback;
    frameSequence = 0;
    await ensureLandmarker(options || {}, "VIDEO");

    stream = await navigator.mediaDevices.getUserMedia({
      audio: false,
      video: {
        facingMode: "user",
        width: { ideal: 480 },
        height: { ideal: 360 },
        frameRate: { ideal: 24, max: 24 },
      },
    }).catch((err) => {
      const name = err && err.name ? err.name : "Error";
      const msg = err && err.message ? err.message : String(err);
      // Bubble a clear permission error for Flutter HUD / retry.
      throw new Error(`${name}: ${msg}`);
    });

    video = document.createElement("video");
    video.setAttribute("playsinline", "true");
    video.muted = true;
    video.autoplay = true;
    video.srcObject = stream;
    video.style.cssText =
      "width:100%;height:100%;object-fit:cover;transform:scaleX(-1);";

    const wrap = ensurePreview();
    wrap.innerHTML = "";
    wrap.appendChild(video);
    await video.play();

    cancelAnimationFrame(rafId);
    lastVideoTime = -1;
    lastDetectMs = 0;
    detectLoop();
    console.info("[sieHandLandmarker] live VIDEO started");
    return { ok: true };
  },

  stopLive() {
    cancelAnimationFrame(rafId);
    rafId = 0;
    liveCallback = null;
    if (stream) {
      stream.getTracks().forEach((t) => t.stop());
      stream = null;
    }
    if (video) {
      video.srcObject = null;
      video.remove();
      video = null;
    }
    removePreview();
  },

  detectRgba(rgba, width, height) {
    if (!handLandmarker) {
      return JSON.stringify({
        hands: [],
        inferMs: 0,
        error: "not_initialized",
      });
    }
    if (runningMode !== "IMAGE") {
      return JSON.stringify({
        hands: [],
        inferMs: 0,
        error: "wrong_mode",
      });
    }
    const t0 = performance.now();
    const imageData = new ImageData(
      rgba instanceof Uint8ClampedArray ? rgba : new Uint8ClampedArray(rgba),
      width,
      height,
    );
    const result = handLandmarker.detect(imageData);
    return JSON.stringify(packHands(result, performance.now() - t0));
  },

  dispose() {
    window.sieHandLandmarker.stopLive();
    try {
      handLandmarker?.close?.();
    } catch (_) {}
    handLandmarker = null;
    runningMode = "IMAGE";
  },
};

console.info("[sieHandLandmarker] bridge loaded");

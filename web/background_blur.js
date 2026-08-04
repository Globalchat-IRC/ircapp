// Helper para desenfoque de fondo con MediaPipe Selfie Segmentation.
// Expone window.backgroundBlur.start(video, canvas) y window.backgroundBlur.stop().
(function() {
  'use strict';

  var SelfieSegmentation = window.SelfieSegmentation;
  var currentRafId = null;
  var selfie = null;
  var running = false;
  var srcVideo = null;
  var dstCanvas = null;
  var ctx = null;
  var lastSegmentation = null;
  var segmentQueue = [];
  var outputType = 'selfie'; // 'selfie' or 'background'

  function loadScript(url) {
    return new Promise(function(resolve, reject) {
      var script = document.createElement('script');
      script.src = url;
      script.crossOrigin = 'anonymous';
      script.onload = function() { resolve(); };
      script.onerror = function() { reject(new Error('No se pudo cargar ' + url)); };
      document.head.appendChild(script);
    });
  }

  function ensureMediaPipe() {
    if (window.SelfieSegmentation) return Promise.resolve();
    return Promise.all([
      loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js'),
      loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/control_utils/control_utils.js'),
      loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/drawing_utils/drawing_utils.js'),
      loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/selfie_segmentation/selfie_segmentation.js'),
    ]).then(function() {
      if (!window.SelfieSegmentation) throw new Error('SelfieSegmentation no disponible');
    });
  }

  function createSegmenter() {
    var segmenter = new window.SelfieSegmentation({
      locateFile: function(file) {
        return 'https://cdn.jsdelivr.net/npm/@mediapipe/selfie_segmentation/' + file;
      },
    });
    segmenter.setOptions({
      modelSelection: 1,
      selfieMode: true,
    });
    segmenter.onResults(function(results) {
      lastSegmentation = results;
      if (segmentQueue.length > 0) {
        segmentQueue.shift()(results);
      }
    });
    return segmenter;
  }

  function stackBlurCanvasRGB(canvas, topX, topY, width, height, radius) {
    // Simple box blur fallback; no external dependencies.
    if (radius < 1) return;
    var ctx = canvas.getContext('2d');
    var imgData = ctx.getImageData(topX, topY, width, height);
    var data = imgData.data;
    var w = width;
    var h = height;
    var wm = w - 1;
    var hm = h - 1;
    var wh = w * h;
    var div = radius + radius + 1;
    var r = new Int32Array(wh);
    var g = new Int32Array(wh);
    var b = new Int32Array(wh);
    var rsum, gsum, bsum, x, y, i, p, p1, p2, yp, yi, yw;
    var vmin = new Int32Array(Math.max(w, h));
    var vmax = new Int32Array(Math.max(w, h));
    var dv = new Int32Array(256 * div);
    for (i = 0; i < 256 * div; i++) { dv[i] = Math.floor(i / div); }

    yw = yi = 0;
    for (y = 0; y < h; y++) {
      rsum = gsum = bsum = 0;
      for (i = -radius; i <= radius; i++) {
        p = (yi + Math.min(wm, Math.max(i, 0))) * 4;
        rsum += data[p];
        gsum += data[p + 1];
        bsum += data[p + 2];
      }
      for (x = 0; x < w; x++) {
        r[yi] = dv[rsum];
        g[yi] = dv[gsum];
        b[yi] = dv[bsum];
        if (y === 0) {
          vmin[x] = Math.min(x + radius + 1, wm);
          vmax[x] = Math.max(x - radius, 0);
        }
        p1 = (yw + vmin[x]) * 4;
        p2 = (yw + vmax[x]) * 4;
        rsum += data[p1] - data[p2];
        gsum += data[p1 + 1] - data[p2 + 1];
        bsum += data[p1 + 2] - data[p2 + 2];
        yi++;
      }
      yw += w;
    }

    for (x = 0; x < w; x++) {
      rsum = gsum = bsum = 0;
      yp = -radius * w;
      for (i = -radius; i <= radius; i++) {
        yi = Math.max(0, yp) + x;
        rsum += r[yi];
        gsum += g[yi];
        bsum += b[yi];
        yp += w;
      }
      yi = x;
      for (y = 0; y < h; y++) {
        data[yi * 4] = dv[rsum];
        data[yi * 4 + 1] = dv[gsum];
        data[yi * 4 + 2] = dv[bsum];
        if (x === 0) {
          vmin[y] = Math.min(y + radius + 1, hm) * w;
          vmax[y] = Math.max(y - radius, 0) * w;
        }
        p1 = x + vmin[y];
        p2 = x + vmax[y];
        rsum += r[p1] - r[p2];
        gsum += g[p1] - g[p2];
        bsum += b[p1] - b[p2];
        yi += w;
      }
    }

    ctx.putImageData(imgData, topX, topY);
  }

  function renderFrame() {
    if (!running || !srcVideo || !dstCanvas || !selfie) return;
    if (srcVideo.paused || srcVideo.ended || srcVideo.readyState < 2) {
      currentRafId = requestAnimationFrame(renderFrame);
      return;
    }

    var w = dstCanvas.width;
    var h = dstCanvas.height;
    if (!w || !h) {
      currentRafId = requestAnimationFrame(renderFrame);
      return;
    }

    if (ctx) {
      if (lastSegmentation && lastSegmentation.segmentationMask) {
        drawSegmentation(lastSegmentation);
        currentRafId = requestAnimationFrame(function() {
          selfie.send({ image: srcVideo }).catch(function(e) { console.error('SelfieSegmentation send error', e); });
        });
      } else {
        currentRafId = requestAnimationFrame(renderFrame);
      }
    }
  }

  function drawSegmentation(results) {
    var w = dstCanvas.width;
    var h = dstCanvas.height;
    ctx.save();
    ctx.clearRect(0, 0, w, h);

    // Draw blurred background
    ctx.drawImage(srcVideo, 0, 0, w, h);
    // Apply blur via offscreen canvas
    var blurCanvas = document.createElement('canvas');
    blurCanvas.width = w;
    blurCanvas.height = h;
    var blurCtx = blurCanvas.getContext('2d');
    blurCtx.drawImage(srcVideo, 0, 0, w, h);
    stackBlurCanvasRGB(blurCanvas, 0, 0, w, h, 15);

    // Draw original person on top using mask
    ctx.drawImage(results.segmentationMask, 0, 0, w, h);
    ctx.globalCompositeOperation = 'source-in';
    ctx.drawImage(srcVideo, 0, 0, w, h);
    ctx.globalCompositeOperation = 'destination-over';
    ctx.drawImage(blurCanvas, 0, 0, w, h);
    ctx.restore();
  }

  window.backgroundBlur = {
    start: function(video, canvas) {
      return new Promise(function(resolve, reject) {
        if (running) {
          window.backgroundBlur.stop();
        }
        srcVideo = video;
        dstCanvas = canvas;
        ctx = canvas.getContext('2d');
        ensureMediaPipe()
          .then(function() {
            selfie = createSegmenter();
            running = true;
            return selfie.send({ image: video });
          })
          .then(function() {
            renderFrame();
            resolve();
          })
          .catch(function(e) {
            console.error('Background blur start error:', e);
            reject(e);
          });
      });
    },
    stop: function() {
      running = false;
      if (currentRafId) {
        cancelAnimationFrame(currentRafId);
        currentRafId = null;
      }
      if (selfie && selfie.close) {
        try { selfie.close(); } catch (e) {}
      }
      selfie = null;
      ctx = null;
      srcVideo = null;
      dstCanvas = null;
      lastSegmentation = null;
      segmentQueue = [];
    }
  };
})();

#!/usr/bin/env node
/**
 * Script Node.js con Playwright para extraer el stream de audio de una sesión grabada de Mixcloud
 * Uso: node mixcloud_recorded_stream_playwright.js https://www.mixcloud.com/djsonic_vlc/session-name/
 */

// Configurar variables de entorno ANTES de requerir Playwright
process.env.PLAYWRIGHT_BROWSERS_PATH = '/media/globalchat/tmp/.playwright';
process.env.TMPDIR = '/media/globalchat/tmp';
process.env.TMP = '/media/globalchat/tmp';

let playwright;
try {
  playwright = require('playwright');
} catch (e) {
  const result = {
    success: false,
    stream_url: '',
    error: 'Playwright no está instalado: ' + e.message,
    message: 'Error: Playwright no está disponible',
    timestamp: Math.floor(Date.now() / 1000)
  };
  process.stdout.write(JSON.stringify(result) + '\n');
  process.exit(1);
}

const { chromium } = playwright;
const fs = require('fs');
const cloudcastUrl = process.argv[2] || '';

if (!cloudcastUrl) {
  const result = {
    success: false,
    stream_url: '',
    error: 'No se proporcionó la URL de la sesión grabada',
    message: 'Uso: node mixcloud_recorded_stream_playwright.js <URL>',
    timestamp: Math.floor(Date.now() / 1000)
  };
  process.stdout.write(JSON.stringify(result) + '\n');
  process.exit(1);
}

(async () => {
  let browser;
  let streamUrl = null;
  
  try {
    // Configurar directorio temporal
    const tmpDir = '/media/globalchat/tmp';
    if (!fs.existsSync(tmpDir)) {
      try {
        fs.mkdirSync(tmpDir, { recursive: true, mode: 0o777 });
      } catch (e) {
        throw new Error(`No se pudo crear el directorio temporal: ${tmpDir}`);
      }
    }
    
    // Configurar directorio de datos de usuario
    const userDataDir = `${tmpDir}/playwright_user_data`;
    if (!fs.existsSync(userDataDir)) {
      try {
        fs.mkdirSync(userDataDir, { recursive: true, mode: 0o777 });
      } catch (e) {
        // Continuar aunque falle
      }
    }
    
    console.error(`🎵 [Playwright Recorded] Iniciando navegador para: ${cloudcastUrl}`);
    
    // Lanzar Chromium en modo headless
    browser = await chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-web-security',
        '--disable-features=IsolateOrigins,site-per-process',
      ],
    });
    
    const context = await browser.newContext({
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      viewport: { width: 1920, height: 1080 },
    });
    
    const page = await context.newPage();
    
    console.error(`🎵 [Playwright Recorded] Navegando a: ${cloudcastUrl}`);
    
    // Navegar a la página de la sesión grabada
    await page.goto(cloudcastUrl, {
      waitUntil: 'networkidle',
      timeout: 30000,
    });
    
    // Esperar a que se cargue el reproductor
    await page.waitForTimeout(3000);
    
    console.error(`🎵 [Playwright Recorded] Buscando URL del stream de audio...`);
    
    // Intentar obtener la URL del stream de varias formas
    // 1. Buscar en el objeto window.__PRELOADED_STATE__ o similar
    streamUrl = await page.evaluate(() => {
      // Buscar en el estado de la aplicación
      const scripts = Array.from(document.querySelectorAll('script'));
      for (const script of scripts) {
        const content = script.textContent || '';
        // Buscar URLs HLS con patrón .urlset/index.m3u8 (prioridad)
        const hlsUrlsetMatch = content.match(/https?:\/\/audio\.mixcloud\.stream\/secure\/hls\/[^"'\s]+\.urlset\/index\.m3u8/i);
        if (hlsUrlsetMatch) {
          return hlsUrlsetMatch[0];
        }
        // Buscar URLs HLS .m3u8
        const hlsMatch = content.match(/https?:\/\/audio\.mixcloud\.stream\/secure\/hls\/[^"'\s]+\.m3u8/i);
        if (hlsMatch) {
          return hlsMatch[0];
        }
        // Buscar en JSON embebido
        try {
          const jsonMatch = content.match(/"streamUrl"\s*:\s*"([^"]+)"/);
          if (jsonMatch && jsonMatch[1].includes('.m3u8')) {
            return jsonMatch[1];
          }
        } catch (e) {
          // Continuar
        }
      }
      return null;
    });
    
    // 2. Si no se encontró, buscar en las peticiones de red
    if (!streamUrl) {
      console.error(`🎵 [Playwright Recorded] Buscando en peticiones de red...`);
      const responses = [];
      page.on('response', (response) => {
        const url = response.url();
        // Priorizar URLs HLS con .urlset/index.m3u8
        if (url.includes('.urlset/index.m3u8') || url.includes('audio.mixcloud.stream') && url.includes('.m3u8')) {
          responses.unshift(url); // Agregar al inicio
        } else if (url.match(/\.(m3u8)/i) || (url.includes('stream') && url.includes('audio'))) {
          responses.push(url);
        }
      });
      
      // Intentar hacer play en el reproductor
      try {
        await page.evaluate(() => {
          const playButton = document.querySelector('button[aria-label*="Play"], button[aria-label*="Reproducir"], .play-button, [data-testid="play-button"]');
          if (playButton) {
            playButton.click();
          }
        });
        await page.waitForTimeout(3000); // Esperar más tiempo para que cargue el stream
      } catch (e) {
        // Ignorar errores
      }
      
      if (responses.length > 0) {
        streamUrl = responses[0];
      }
    }
    
    // 3. Buscar en el elemento de audio/video
    if (!streamUrl) {
      streamUrl = await page.evaluate(() => {
        const audio = document.querySelector('audio');
        if (audio && audio.src) {
          return audio.src;
        }
        const video = document.querySelector('video');
        if (video && video.src) {
          return video.src;
        }
        return null;
      });
    }
    
    await browser.close();
    
    if (streamUrl) {
      const result = {
        success: true,
        stream_url: streamUrl,
        cloudcast_url: cloudcastUrl,
        timestamp: Math.floor(Date.now() / 1000)
      };
      process.stdout.write(JSON.stringify(result) + '\n');
      console.error(`✅ [Playwright Recorded] Stream encontrado: ${streamUrl}`);
    } else {
      const result = {
        success: false,
        stream_url: '',
        cloudcast_url: cloudcastUrl,
        error: 'No se pudo encontrar la URL del stream de audio',
        message: 'El reproductor de Mixcloud no expone la URL del stream directamente',
        timestamp: Math.floor(Date.now() / 1000)
      };
      process.stdout.write(JSON.stringify(result) + '\n');
      console.error(`❌ [Playwright Recorded] No se encontró la URL del stream`);
      process.exit(1);
    }
    
  } catch (error) {
    const result = {
      success: false,
      stream_url: '',
      cloudcast_url: cloudcastUrl,
      error: error.message,
      message: 'Error al extraer el stream con Playwright',
      timestamp: Math.floor(Date.now() / 1000)
    };
    process.stdout.write(JSON.stringify(result) + '\n');
    console.error(`❌ [Playwright Recorded] Error: ${error.message}`);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
})();

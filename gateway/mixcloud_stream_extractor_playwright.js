#!/usr/bin/env node
/**
 * Script Node.js con Playwright para extraer el stream HLS de Mixcloud Live
 * Uso: node mixcloud_stream_extractor_playwright.js djsonic_vlc
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
    is_live: false,
    username: process.argv[2] || 'djsonic_vlc',
    error: 'Playwright no está instalado: ' + e.message,
    message: 'Error: Playwright no está disponible. Ejecuta: npm install playwright',
    timestamp: Math.floor(Date.now() / 1000)
  };
  process.stdout.write(JSON.stringify(result) + '\n');
  process.exit(1);
}

const { chromium } = playwright;
const fs = require('fs');
const username = process.argv[2] || 'djsonic_vlc';
const url = `https://www.mixcloud.com/live/${username}/`;

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
        // Ignorar error
      }
    }
    
    console.error(`🎵 [Playwright] Iniciando navegador...`);
    
    // Usar Chromium del sistema si está disponible
    let executablePath = null;
    if (fs.existsSync('/usr/bin/chromium')) {
      executablePath = '/usr/bin/chromium';
      console.error(`✅ [Playwright] Usando Chromium del sistema: ${executablePath}`);
    }
    
    browser = await chromium.launch({
      headless: true,
      executablePath: executablePath,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-web-security',
        '--single-process',
        '--no-zygote',
        '--disable-crashpad',
        '--disable-crash-reporter',
        `--crash-dumps-dir=${tmpDir}/crashpad`,
        `--breakpad-dump-location=${tmpDir}/crashpad`
      ]
    });

    const context = await browser.newContext({
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    });
    
    const page = await context.newPage();
    
    // Interceptar peticiones de red para capturar el stream
    let streamFound = false;
    page.on('response', async (response) => {
      const responseUrl = response.url();
      if (responseUrl.includes('.m3u8') && responseUrl.includes('mixcloud')) {
        // Preferir master.m3u8 sobre variantes específicas
        if (!streamUrl || responseUrl.includes('master.m3u8')) {
          streamUrl = responseUrl;
          console.error(`✅ [Playwright] Stream encontrado en petición: ${responseUrl}`);
          if (responseUrl.includes('master.m3u8')) {
            streamFound = true;
          }
        }
      }
    });
    
    // Cargar la página
    console.error(`🎵 [Playwright] Cargando página: ${url}`);
    try {
      await page.goto(url, { 
        waitUntil: 'domcontentloaded',
        timeout: 30000 
      });
    } catch (e) {
      // Si hay timeout pero ya tenemos el stream, continuar
      if (!streamUrl) {
        throw e;
      }
    }

    // Esperar a que se cargue el stream (máximo 15 segundos)
    for (let i = 0; i < 15 && !streamFound; i++) {
      await page.waitForTimeout(1000);
      if (streamUrl && streamUrl.includes('master.m3u8')) {
        break;
      }
    }

    // Intentar extraer la URL del stream del DOM si no se capturó en las peticiones
    if (!streamUrl) {
      streamUrl = await page.evaluate(() => {
        // Buscar en scripts
        const scripts = Array.from(document.querySelectorAll('script'));
        for (const script of scripts) {
          const content = script.textContent || script.innerHTML;
          const m3u8Match = content.match(/https:\/\/live-[^"'\s]+\.mixcloud\.com\/[^"'\s]+\.m3u8[^"'\s]*/);
          if (m3u8Match) {
            return m3u8Match[0];
          }
        }

        // Buscar en elementos de video/audio
        const videoElements = document.querySelectorAll('video, audio');
        for (const element of videoElements) {
          if (element.src && element.src.includes('.m3u8')) {
            return element.src;
          }
          if (element.currentSrc && element.currentSrc.includes('.m3u8')) {
            return element.currentSrc;
          }
        }

        return null;
      });
    }

    if (streamUrl && streamUrl.includes('.m3u8') && streamUrl.includes('mixcloud')) {
      const result = {
        success: true,
        stream_url: streamUrl,
        username: username,
        is_live: true,
        timestamp: Math.floor(Date.now() / 1000),
        format: 'HLS',
        type: 'm3u8'
      };
      // Imprimir solo el JSON a stdout (los mensajes de debug van a stderr)
      process.stdout.write(JSON.stringify(result) + '\n');
      process.exit(0);
    }

    // No se encontró el stream
    const result = {
      success: false,
      is_live: false,
      username: username,
      message: 'No se pudo extraer la URL del stream. El stream puede no estar en vivo o Mixcloud ha cambiado su estructura.',
      timestamp: Math.floor(Date.now() / 1000)
    };
    process.stdout.write(JSON.stringify(result) + '\n');
    process.exit(0);

  } catch (error) {
    const result = {
      success: false,
      is_live: false,
      username: username,
      error: error.message,
      message: 'Error al extraer el stream con Playwright',
      timestamp: Math.floor(Date.now() / 1000)
    };
    process.stdout.write(JSON.stringify(result) + '\n');
    console.error(`❌ [Playwright] Error: ${error.message}`);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
})();

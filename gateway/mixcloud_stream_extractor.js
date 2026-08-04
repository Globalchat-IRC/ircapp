#!/usr/bin/env node
/**
 * Script Node.js con Puppeteer para extraer el stream HLS de Mixcloud Live
 * Uso: node mixcloud_stream_extractor.js djsonic_vlc
 */

// Configurar variables de entorno ANTES de requerir Puppeteer
process.env.PUPPETEER_CACHE_DIR = '/media/globalchat/tmp/.puppeteer_cache';
process.env.TMPDIR = '/media/globalchat/tmp';
process.env.TMP = '/media/globalchat/tmp';

const puppeteer = require('puppeteer');
const fs = require('fs');
const username = process.argv[2] || 'djsonic_vlc';
const url = `https://www.mixcloud.com/live/${username}/`;

(async () => {
  let browser;
  let streamUrl = null;
  
  try {
    // Configurar directorio temporal y cache para Puppeteer
    const tmpDir = '/media/globalchat/tmp';
    process.env.TMPDIR = tmpDir;
    process.env.TMP = tmpDir;
    process.env.PUPPETEER_CACHE_DIR = `${tmpDir}/.puppeteer_cache`;
    
    // Asegurar que el directorio existe
    if (!fs.existsSync(tmpDir)) {
      try {
        fs.mkdirSync(tmpDir, { recursive: true, mode: 0o777 });
      } catch (e) {
        throw new Error(`No se pudo crear el directorio temporal: ${tmpDir}`);
      }
    }
    
    // Crear directorio de cache de Puppeteer
    const cacheDir = process.env.PUPPETEER_CACHE_DIR;
    if (!fs.existsSync(cacheDir)) {
      try {
        fs.mkdirSync(cacheDir, { recursive: true, mode: 0o777 });
      } catch (e) {
        // Ignorar error
      }
    }
    
    // Configurar directorio de datos de usuario para Chrome (evita usar /tmp)
    const userDataDir = `${tmpDir}/puppeteer_user_data`;
    if (!fs.existsSync(userDataDir)) {
      try {
        fs.mkdirSync(userDataDir, { recursive: true, mode: 0o777 });
      } catch (e) {
        // Ignorar error
      }
    }
    
    // Iniciar navegador headless con configuración mínima
    const launchOptions = {
      headless: 'new',
      userDataDir: userDataDir,
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
        '--disable-breakpad',
        `--crash-dumps-dir=${tmpDir}`,
        `--user-data-dir=${userDataDir}`,
        `--homedir=${tmpDir}`,
        '--disable-software-rasterizer',
        '--disable-background-networking',
        '--disable-background-timer-throttling',
        '--disable-backgrounding-occluded-windows',
        '--disable-client-side-phishing-detection',
        '--disable-default-apps',
        '--disable-hang-monitor',
        '--disable-popup-blocking',
        '--disable-prompt-on-repost',
        '--disable-sync',
        '--disable-translate',
        '--metrics-recording-only',
        '--no-first-run',
        '--safebrowsing-disable-auto-update',
        '--enable-automation',
        '--password-store=basic',
        '--use-mock-keychain'
      ]
    };
    
    // Usar Chromium del sistema (más confiable que descargar Chrome)
    if (fs.existsSync('/usr/bin/chromium')) {
      launchOptions.executablePath = '/usr/bin/chromium';
      console.error(`✅ [Puppeteer] Usando Chromium del sistema: /usr/bin/chromium`);
    } else {
      // Intentar obtener el path de Chrome de Puppeteer
      try {
        const chromePath = puppeteer.executablePath();
        if (chromePath && fs.existsSync(chromePath)) {
          launchOptions.executablePath = chromePath;
          console.error(`✅ [Puppeteer] Usando Chrome de Puppeteer: ${chromePath}`);
        } else {
          throw new Error('Chrome no encontrado. Por favor instale Chromium: sudo apt-get install chromium');
        }
      } catch (e) {
        throw new Error(`No se encontró Chrome ni Chromium: ${e.message}`);
      }
    }
    
    browser = await puppeteer.launch(launchOptions);

    const page = await browser.newPage();
    
    // Interceptar peticiones de red ANTES de cargar la página para capturar el stream
    page.on('response', async (response) => {
      const responseUrl = response.url();
      if (responseUrl.includes('.m3u8') && responseUrl.includes('mixcloud')) {
        streamUrl = responseUrl;
        console.error(`✅ [Puppeteer] Stream encontrado en petición: ${responseUrl}`);
      }
    });
    
    // Configurar User-Agent
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    
    // Esperar a que se cargue la página y el JavaScript
    console.error(`🎵 [Puppeteer] Cargando página: ${url}`);
    await page.goto(url, { 
      waitUntil: 'networkidle2',
      timeout: 30000 
    });

    // Esperar un poco más para que se cargue el stream
    await page.waitForTimeout(8000);

    // Intentar extraer la URL del stream de varias formas (si no se capturó en las peticiones)
    if (!streamUrl) {
      streamUrl = await page.evaluate(() => {
        // Método 1: Buscar en el HTML renderizado
        const scripts = Array.from(document.querySelectorAll('script'));
        for (const script of scripts) {
          const content = script.textContent || script.innerHTML;
          // Buscar URLs de stream m3u8
          const m3u8Match = content.match(/https:\/\/live-[^"'\s]+\.mixcloud\.com\/[^"'\s]+\.m3u8[^"'\s]*/);
          if (m3u8Match) {
            return m3u8Match[0];
          }
        }

        // Método 2: Buscar en variables JavaScript globales
        if (window.__INITIAL_STATE__) {
          const state = window.__INITIAL_STATE__;
          if (state.live && state.live.streamUrl) {
            return state.live.streamUrl;
          }
        }

        // Método 3: Buscar en el app-context
        const appContext = document.querySelector('script#app-context');
        if (appContext) {
          try {
            const data = JSON.parse(appContext.textContent);
            if (data.live && data.live.streamUrl) {
              return data.live.streamUrl;
            }
          } catch (e) {
            // Ignorar errores de parsing
          }
        }
      
        // Método 4: Buscar elementos de video/audio
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

    const finalStreamUrl = streamUrl;

    if (finalStreamUrl) {
      // Verificar que es una URL válida de Mixcloud Live
      if (finalStreamUrl.includes('.m3u8') && finalStreamUrl.includes('mixcloud')) {
        const result = {
          success: true,
          stream_url: finalStreamUrl,
          username: username,
          is_live: true,
          timestamp: Math.floor(Date.now() / 1000),
          format: 'HLS',
          type: 'm3u8'
        };
        console.log(JSON.stringify(result));
        process.exit(0);
      }
    }

    // No se encontró el stream
    const result = {
      success: false,
      is_live: false,
      username: username,
      message: 'No se pudo extraer la URL del stream. El stream puede no estar en vivo o Mixcloud ha cambiado su estructura.',
      timestamp: Math.floor(Date.now() / 1000)
    };
    console.log(JSON.stringify(result));
    process.exit(0);

  } catch (error) {
    const result = {
      success: false,
      is_live: false,
      username: username,
      error: error.message,
      message: 'Error al extraer el stream con Puppeteer',
      timestamp: Math.floor(Date.now() / 1000)
    };
    console.log(JSON.stringify(result));
    console.error(`❌ [Puppeteer] Error: ${error.message}`);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
})();

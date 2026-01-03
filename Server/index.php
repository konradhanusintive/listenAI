<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");

$dataFile = 'data.json';

// --- BACKEND (API) ---
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);

    if (isset($data['text'])) {
        // Zapisujemy cały obiekt konfiguracji (text, sourceLang, targetLang)
        file_put_contents($dataFile, json_encode($data));
        echo json_encode(["status" => "success"]);
    } else {
        http_response_code(400);
        echo json_encode(["status" => "error"]);
    }
    exit;
}

if (isset($_GET['action']) && $_GET['action'] === 'fetch') {
    if (file_exists($dataFile)) {
        echo file_get_contents($dataFile);
    } else {
        // Domyślny stan
        echo json_encode([
            "text" => "", 
            "sourceLang" => "en", 
            "targetLang" => "pl"
        ]);
    }
    exit;
}
?>
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ListenAI - Neural Link</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap');

        :root {
            --neon-blue: #00f3ff;
            --neon-pink: #bc13fe;
            --neon-green: #0aff0a;
            --bg-color: #050505;
            --panel-bg: rgba(20, 20, 20, 0.7);
        }

        body {
            background-color: var(--bg-color);
            color: #e0e0e0;
            font-family: 'JetBrains Mono', monospace;
            margin: 0;
            display: flex;
            flex-direction: column;
            height: 100vh;
            overflow: hidden;
            background-image: 
                linear-gradient(rgba(18, 16, 16, 0) 50%, rgba(0, 0, 0, 0.25) 50%), 
                linear-gradient(90deg, rgba(255, 0, 0, 0.06), rgba(0, 255, 0, 0.02), rgba(0, 0, 255, 0.06));
            background-size: 100% 2px, 3px 100%;
        }

        .container {
            display: flex;
            flex-direction: column;
            height: 100%;
            padding: 20px;
            box-sizing: border-box;
            gap: 20px;
        }

        .panel {
            flex: 1;
            background: var(--panel-bg);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 8px;
            padding: 20px;
            position: relative;
            box-shadow: 0 0 15px rgba(0,0,0,0.8);
            display: flex;
            flex-direction: column;
            transition: border-color 0.3s;
        }

        .panel.active {
            border-color: var(--neon-blue);
            box-shadow: 0 0 20px rgba(0, 243, 255, 0.1);
        }

        .panel-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
            border-bottom: 1px solid rgba(255,255,255,0.1);
            padding-bottom: 10px;
        }

        .label {
            font-size: 0.8rem;
            color: var(--neon-blue);
            text-transform: uppercase;
            letter-spacing: 2px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .lang-badge {
            background: rgba(255,255,255,0.1);
            padding: 2px 8px;
            border-radius: 4px;
            color: white;
            font-size: 0.8rem;
        }

        .content-area {
            flex: 1;
            overflow-y: auto;
            font-size: 1.4rem;
            line-height: 1.5;
            white-space: pre-wrap;
        }

        /* Cursor */
        .cursor::after {
            content: '█';
            color: var(--neon-pink);
            animation: blink 1s steps(2) infinite;
        }

        /* Fullscreen Overlay */
        #fullscreen-overlay {
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: black;
            z-index: 100;
            display: none;
            justify-content: center;
            align-items: center;
            padding: 50px;
            box-sizing: border-box;
        }

        #fs-text {
            font-size: 3.5rem;
            color: var(--neon-green);
            text-align: center;
            max-width: 95%;
            line-height: 1.3;
            text-shadow: 0 0 30px rgba(10, 255, 10, 0.3);
        }

        .cinema-btn {
            position: absolute;
            bottom: 20px; right: 20px;
            background: var(--neon-pink);
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            z-index: 10;
            font-family: inherit;
            text-transform: uppercase;
            font-weight: bold;
        }

        @keyframes blink { 0% { opacity: 1; } 50% { opacity: 0; } 100% { opacity: 1; } }
    </style>
</head>
<body>

    <div class="container">
        <!-- SOURCE -->
        <div class="panel active">
            <div class="panel-header">
                <div class="label">INPUT STREAM <span id="source-badge" class="lang-badge">EN</span></div>
            </div>
            <div id="source-content" class="content-area cursor"></div>
        </div>

        <!-- TRANSLATION -->
        <div class="panel">
            <div class="panel-header">
                <div class="label" style="color: var(--neon-pink)">TRANSLATED OUTPUT <span id="target-badge" class="lang-badge">PL</span></div>
            </div>
            <div id="translated-content" class="content-area"></div>
        </div>
    </div>

    <button class="cinema-btn" onclick="openFullscreen()">[ PEŁNY EKRAN ]</button>

    <div id="fullscreen-overlay" onclick="closeFullscreen()">
        <div id="fs-text"></div>
    </div>

    <script>
        const sourceEl = document.getElementById('source-content');
        const translatedEl = document.getElementById('translated-content');
        const fsTextEl = document.getElementById('fs-text');
        
        const sourceBadge = document.getElementById('source-badge');
        const targetBadge = document.getElementById('target-badge');

        // State
        let serverText = "";      // Text from server
        let displayedText = "";   // Text currently shown (typed)
        let config = { source: 'en', target: 'pl' };
        
        let isTyping = false;
        let translationTimeout = null;

        async function loop() {
            try {
                const res = await fetch('?action=fetch');
                const data = await res.json();
                
                // 1. Check Languages
                if (data.sourceLang && data.sourceLang !== config.source) {
                    config.source = data.sourceLang;
                    sourceBadge.innerText = config.source.toUpperCase();
                }
                if (data.targetLang && data.targetLang !== config.target) {
                    config.target = data.targetLang;
                    targetBadge.innerText = config.target.toUpperCase();
                    // Force re-translation if target changed
                    triggerTranslation();
                }

                // 2. Check Text
                const newText = data.text || "";
                
                if (newText !== serverText) {
                    // Detect Reset
                    if (newText === "" || newText.length < serverText.length) {
                         // Hard reset or deletion
                         serverText = newText;
                         displayedText = "";
                         sourceEl.innerText = "";
                         translatedEl.innerText = "";
                         fsTextEl.innerText = "";
                         typeWriter(newText);
                    } else {
                        // Append
                        const prevServerText = serverText;
                        serverText = newText;
                        
                        // Check if we can append
                        if (serverText.startsWith(prevServerText)) {
                            // Only type the new part
                            // However, we must ensure displayedText matches prevServerText
                            // If typing was too slow, displayedText might be behind.
                            // We should simply append the diff between serverText and *what we know we processed*.
                            
                            // Let's use simpler logic: 
                            // displayedText tracks what has been *queued* to type or fully typed.
                            // Actually, let's just diff against displayedText if it's consistent.
                            
                            // Safe approach: Calculate diff from serverText vs prevServerText
                            const diff = serverText.substring(prevServerText.length);
                            typeWriter(diff);
                        } else {
                            // Content changed radically (middle edit?), reset visual
                            displayedText = "";
                            sourceEl.innerText = "";
                            typeWriter(serverText);
                        }
                    }
                }

            } catch (e) { console.error(e); }
            
            setTimeout(loop, 500);
        }

        function typeWriter(chunk) {
            if (!chunk) return;
            
            let i = 0;
            const delay = chunk.length > 20 ? 10 : 30; // Adaptive speed

            function step() {
                if (i < chunk.length) {
                    const char = chunk.charAt(i);
                    sourceEl.innerText += char;
                    displayedText += char; // Update our tracker
                    sourceEl.scrollTop = sourceEl.scrollHeight;
                    i++;
                    setTimeout(step, delay);
                } else {
                    // Finished typing this chunk
                    triggerTranslation();
                }
            }
            step();
        }

        function triggerTranslation() {
            clearTimeout(translationTimeout);
            translationTimeout = setTimeout(translate, 500);
        }

        async function translate() {
            if (!displayedText) {
                translatedEl.innerText = "";
                fsTextEl.innerText = "";
                return;
            }

            const pair = `${config.source}|${config.target}`;
            const textToTranslate = displayedText; // Use what's visible

            try {
                const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(textToTranslate)}&langpair=${pair}`;
                const res = await fetch(url);
                const json = await res.json();

                if (json.responseData) {
                    const trans = json.responseData.translatedText;
                    translatedEl.innerText = trans;
                    fsTextEl.innerText = trans;
                    translatedEl.scrollTop = translatedEl.scrollHeight;
                }
            } catch (e) {
                console.error(e);
            }
        }

        function openFullscreen() {
            document.getElementById('fullscreen-overlay').style.display = 'flex';
            if(document.documentElement.requestFullscreen) document.documentElement.requestFullscreen();
        }
        function closeFullscreen() {
            document.getElementById('fullscreen-overlay').style.display = 'none';
            if(document.exitFullscreen) document.exitFullscreen();
        }

        loop();
    </script>
</body>
</html>

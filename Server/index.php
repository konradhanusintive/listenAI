<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");

$dataFile = 'data.json';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    if (isset($data['text'])) {
        file_put_contents($dataFile, json_encode($data));
        echo json_encode(["status" => "success"]);
    } else {
        http_response_code(400);
        echo json_encode(["status" => "error"]);
    }
    exit;
}

if (isset($_GET['action']) && $_GET['action'] === 'fetch') {
    if (file_exists($dataFile)) echo file_get_contents($dataFile);
    else echo json_encode(["text" => "", "sourceLang" => "en", "targetLang" => "pl"]);
    exit;
}
?>
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <title>ListenAI - Pro Stream</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;700&display=swap');

        :root {
            --accent: #00f3ff;
            --secondary: #bc13fe;
            --bg: #050505;
            --card-bg: rgba(20, 20, 25, 0.95);
            --text: #eee;
        }

        body {
            background: var(--bg);
            color: var(--text);
            font-family: 'Inter', sans-serif;
            margin: 0;
            display: flex;
            flex-direction: column;
            height: 100vh;
            overflow: hidden;
        }

        .header {
            padding: 15px 30px;
            background: rgba(0,0,0,0.8);
            border-bottom: 1px solid rgba(255,255,255,0.1);
            display: flex; justify-content: space-between; align-items: center;
        }
        .logo { font-family: 'JetBrains Mono'; font-weight: 700; display: flex; align-items: center; gap: 10px; }
        .dot { width: 8px; height: 8px; background: #333; border-radius: 50%; }
        .dot.active { background: var(--accent); box-shadow: 0 0 10px var(--accent); }

        .grid {
            display: flex; flex: 1; padding: 20px; gap: 20px; overflow: hidden;
        }

        .column {
            flex: 1; display: flex; flex-direction: column;
            background: rgba(255,255,255,0.02);
            border-radius: 12px; border: 1px solid rgba(255,255,255,0.05);
            overflow: hidden;
        }

        .col-head {
            padding: 15px; font-family: 'JetBrains Mono'; font-size: 0.8rem; text-transform: uppercase; color: #888;
            border-bottom: 1px solid rgba(255,255,255,0.05);
        }

        .scroll-zone {
            flex: 1; overflow-y: auto; padding: 20px; scroll-behavior: smooth;
        }

        .block {
            margin-bottom: 15px; padding: 15px;
            background: var(--card-bg);
            border-left: 3px solid rgba(255,255,255,0.1);
            border-radius: 0 8px 8px 0;
            font-size: 1.15rem; line-height: 1.5;
            transition: all 0.2s ease;
        }
        
        .block.source { border-left-color: var(--accent); }
        .block.target { border-left-color: var(--secondary); color: #fff; }
        
        .cursor::after {
            content: '█'; color: var(--accent); animation: blink 0.8s infinite; margin-left: 5px; font-size: 0.8em;
        }

        @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }

        /* Fullscreen */
        #fs { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: #000; z-index: 100; display: none; padding: 50px 10vw; box-sizing: border-box; overflow-y: auto; }
        #fs-content { font-size: 2.8rem; line-height: 1.4; color: #fff; margin: auto 0; }
        #fs-close { position: fixed; top: 30px; right: 30px; color: #666; cursor: pointer; font-family: 'JetBrains Mono'; border: 1px solid #333; padding: 5px 10px; }
        .btn { background: transparent; border: 1px solid var(--secondary); color: var(--secondary); padding: 5px 15px; cursor: pointer; border-radius: 4px; font-weight: bold; }
    </style>
</head>
<body>

<div class="header">
    <div class="logo"><div class="dot" id="status"></div> LISTEN AI // PRO</div>
    <button class="btn" onclick="toggleFS()">PEŁNY EKRAN</button>
</div>

<div class="grid">
    <div class="column">
        <div class="col-head">WEJŚCIE <span id="s-lang">EN</span></div>
        <div class="scroll-zone" id="box-source"></div>
    </div>
    <div class="column">
        <div class="col-head">TŁUMACZENIE <span id="t-lang">PL</span></div>
        <div class="scroll-zone" id="box-target"></div>
    </div>
</div>

<div id="fs"><div id="fs-close" onclick="toggleFS()">ZAMKNIJ</div><div id="fs-content"></div></div>

<script>
    const boxSource = document.getElementById('box-source');
    const boxTarget = document.getElementById('box-target');
    const fsContent = document.getElementById('fs-content');
    const status = document.getElementById('status');
    
    let config = { source: 'en', target: 'pl' };
    let cache = { blocks: [], translations: [] };

    function scrollToBottom(el) {
        if (el.scrollHeight - el.scrollTop - el.clientHeight < 150) {
            el.scrollTop = el.scrollHeight;
        }
    }

    async function loop() {
        try {
            const res = await fetch('?action=fetch');
            const data = await res.json();
            status.classList.add('active');

            if(data.sourceLang) {
                config.source = data.sourceLang;
                document.getElementById('s-lang').innerText = config.source.toUpperCase();
            }
            if(data.targetLang) {
                config.target = data.targetLang;
                document.getElementById('t-lang').innerText = config.target.toUpperCase();
            }

            const fullText = data.text || "";
            
            if (fullText === "" && cache.blocks.length > 0) {
                boxSource.innerHTML = "";
                boxTarget.innerHTML = "";
                fsContent.innerHTML = "";
                cache = { blocks: [], translations: [] };
            }

            const newBlocks = fullText.split(/\n\n+/).filter(x => x.trim().length > 0);

            for (let i = 0; i < newBlocks.length; i++) {
                const text = newBlocks[i];
                
                // 1. Source
                let sEl = document.getElementById(`s-${i}`);
                if (!sEl) {
                    sEl = document.createElement('div');
                    sEl.id = `s-${i}`;
                    sEl.className = 'block source';
                    boxSource.appendChild(sEl);
                    scrollToBottom(boxSource);
                }

                const currentText = sEl.dataset.fullText || "";
                if (text !== currentText) {
                    sEl.dataset.fullText = text;
                    if (text.startsWith(currentText)) {
                        sEl.innerText += text.substring(currentText.length);
                    } else {
                        sEl.innerText = text;
                    }
                    scrollToBottom(boxSource);
                }

                // 2. Target
                if (cache.blocks[i] !== text || !cache.translations[i]) {
                    cache.blocks[i] = text;
                    
                    let tEl = document.getElementById(`t-${i}`);
                    if (!tEl) {
                        tEl = document.createElement('div');
                        tEl.id = `t-${i}`;
                        tEl.className = 'block target';
                        tEl.innerText = "...";
                        boxTarget.appendChild(tEl);
                        scrollToBottom(boxTarget);
                    }
                    
                    translateLongText(text, i);
                }
            }

        } catch (e) {
            console.error(e);
            status.classList.remove('active');
        }
        setTimeout(loop, 500);
    }

    // Helper to split text by chunks (approx 450 chars) but respecting words
    function splitToChunks(text, limit = 450) {
        if (text.length <= limit) return [text];
        const words = text.split(" ");
        const chunks = [];
        let currentChunk = "";
        
        for (const word of words) {
            if ((currentChunk + word).length > limit) {
                chunks.push(currentChunk.trim());
                currentChunk = word + " ";
            } else {
                currentChunk += word + " ";
            }
        }
        if (currentChunk.trim()) chunks.push(currentChunk.trim());
        return chunks;
    }

    async function translateLongText(text, index) {
        const tEl = document.getElementById(`t-${index}`);
        const pair = `${config.source}|${config.target}`;
        
        const chunks = splitToChunks(text);
        let translatedParts = [];

        try {
            // Process chunks in parallel
            const promises = chunks.map(async (chunk) => {
                const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(chunk)}&langpair=${pair}`;
                const res = await fetch(url);
                const json = await res.json();
                return json.responseData ? json.responseData.translatedText : chunk;
            });

            const results = await Promise.all(promises);
            const fullTranslation = results.join(" ");

            cache.translations[index] = fullTranslation;
            tEl.innerText = fullTranslation;
            updateFullscreen();
            scrollToBottom(boxTarget);

        } catch (e) {
            console.error(e);
            tEl.innerText = "[Błąd limitu API]";
        }
    }

    function updateFullscreen() {
        fsContent.innerText = cache.translations.join('\n\n');
        const fs = document.getElementById('fs');
        if(fs.style.display === 'block') fs.scrollTop = fs.scrollHeight;
    }

    function toggleFS() {
        const fs = document.getElementById('fs');
        fs.style.display = fs.style.display === 'block' ? 'none' : 'block';
        if (fs.style.display === 'block' && document.documentElement.requestFullscreen) {
            document.documentElement.requestFullscreen();
        }
    }
    
    loop();
</script>
</body>
</html>
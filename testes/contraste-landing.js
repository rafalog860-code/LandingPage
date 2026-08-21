// Contraste das paginas do site — a regra que existe para o Rafael parar de pedir.
//
// POR QUE EXISTE (21/08/2026)
// ---------------------------
// Contraste voltou como pedido dele TRES vezes: a T161 (texto das tabelas do
// Faturamento em 1,07:1, preto no preto), a T163 (barra dourada do topo, 2,10:1) e
// agora as telas do cliente da /agenda-global/, que sao cartoes BRANCOS soltos numa
// secao #f8f9fa — 1,03:1 de separacao, ou seja, nenhuma. Tres vezes e' padrao, nao
// azar. A licao da T162 vale aqui igual: regra que depende de alguem lembrar de ler
// e' intencao; esta e' executada.
//
// O QUE ELE CONFERE, E POR QUE SAO DUAS COISAS
// --------------------------------------------
// 1. TEXTO contra o fundo — WCAG AA: 4,5:1 no texto comum, 3:1 no texto grande
//    (>=24px, ou >=18.66px em negrito). E' o que o AppHorarioCheio/testes/contraste.js
//    ja' fazia no painel, e o que pegou a T161 e a T163.
//
// 2. SUPERFICIE contra o fundo de tras. **Esta e' a que faltava.** O defeito das
//    telas do cliente nao era texto: cada tela tinha texto legivel DENTRO dela. Era o
//    cartao branco desaparecendo na pagina quase branca. Um conferidor so' de texto
//    passaria batido — e passou, porque nenhum dos testes de 19/08 olhou isso.
//    A separacao vale pelo melhor entre o fundo do proprio elemento e a cor da borda
//    dele, os dois contra o fundo de tras. Sombra nao conta: ela ajuda o olho, mas nao
//    da' para medir de forma estavel e nao substitui contraste real.
//
// COMO RODAR
//   node LandingPage/testes/contraste-landing.js              (arquivos locais)
//   node LandingPage/testes/contraste-landing.js --site       (o que esta no ar)
//   node LandingPage/testes/contraste-landing.js --larguras 375,1280
//
// Sai com codigo 1 se alguma pagina reprovar, e grava LandingPage/testes/.contraste-ok
// com o hash de cada HTML aprovado. O verificar_fechamento.sh le esse arquivo: mexeu
// no HTML e nao reconferiu, ele bloqueia o fim do turno.
//
// Sem dependencia nova: usa o playwright-core que o Instagram/video ja' tem, com o
// Edge do sistema.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { chromium } = require('../../Instagram/video/node_modules/playwright-core');

const BASE = path.join(__dirname, '..');
const MARCA = path.join(__dirname, '.contraste-ok');

const arg = (nome, padrao) => {
    const i = process.argv.indexOf('--' + nome);
    return i > -1 ? process.argv[i + 1] : padrao;
};
const tem = (nome) => process.argv.includes('--' + nome);

// As 6 paginas do site. Acrescentar pagina nova aqui.
const PAGINAS = [
    ['home', 'index.html', ''],
    ['agenda-global', 'agenda-global/index.html', 'agenda-global/'],
    ['manicure', 'manicure/index.html', 'manicure/'],
    ['clinica-estetica', 'clinica-estetica/index.html', 'clinica-estetica/'],
    ['diferencial', 'diferencial-dos-concorrentes/index.html', 'diferencial-dos-concorrentes/'],
    ['privacidade', 'privacidade/index.html', 'privacidade/'],
];

const LARGURAS = (arg('larguras', '375,1280')).split(',').map(Number);

const MIN_TEXTO = 4.5;
const MIN_TEXTO_GRANDE = 3.0;
// 1,30 nao e' numero da WCAG: a norma nao fala de superficie. Foi calibrado no
// proprio site — o palco azul das telas da' 1,45 e passa; o branco no #f8f9fa que o
// Rafael reprovou da' 1,03 e reprova. Mexer nele so' com um caso real na mao.
const MIN_SUPERFICIE = 1.30;
// A saida perceptual: uma superficie tambem passa se a COR for distinta o bastante,
// mesmo com o mesmo brilho. 8 e' calibrado no proprio site — o palco azul da' ~9 e
// passa; branco no #f8f9fa da' ~1,4 e reprova. (Diferenca perceptivel comeca em ~2,3.)
const MIN_DELTA_E = 8;

function sha(arquivo) {
    return crypto.createHash('sha256').update(fs.readFileSync(arquivo)).digest('hex').slice(0, 16);
}

(async () => {
    const noAr = tem('site');
    const browser = await chromium.launch({ channel: 'msedge', headless: true });
    let falhas = 0;
    const relatorio = [];

    for (const largura of LARGURAS) {
        const ctx = await browser.newContext({
            viewport: { width: largura, height: 900 },
            locale: 'pt-BR',
        });
        const page = await ctx.newPage();

        for (const [nome, arquivo, rota] of PAGINAS) {
            const url = noAr
                ? 'https://horariocheio.com.br/' + rota
                : 'file:///' + path.join(BASE, arquivo).replace(/\\/g, '/');

            await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
            await page.waitForTimeout(400);

            const achados = await page.evaluate(({ MIN_TEXTO, MIN_TEXTO_GRANDE, MIN_SUPERFICIE, MIN_DELTA_E }) => {
                const rgba = (s) => {
                    const n = (s.match(/[\d.]+/g) || []).map(Number);
                    return [n[0] | 0, n[1] | 0, n[2] | 0, n.length > 3 ? n[3] : 1];
                };
                const transparente = (c) => !c || /rgba\(0, 0, 0, 0\)|transparent/.test(c);

                // Empilha a cor sobre o fundo, respeitando alfa. Sem isso uma borda
                // rgb(...) / .22 seria lida como se fosse opaca.
                const sobre = ([r, g, b, a], [R, G, B]) => a >= 1
                    ? [r, g, b]
                    : [r * a + R * (1 - a), g * a + G * (1 - a), b * a + B * (1 - a)];

                const lum = ([r, g, b]) => {
                    const f = (v) => {
                        v /= 255;
                        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
                    };
                    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
                };
                const razao = (A, B) => {
                    const [c, e] = [lum(A), lum(B)].sort((x, y) => y - x);
                    return (c + 0.05) / (e + 0.05);
                };

                // Fundo efetivo. `incluirProprio` decide se o fundo do proprio
                // elemento entra: para o TEXTO dele, entra (o texto de um botao esta
                // sobre o botao); para a SUPERFICIE dele, nao (o que interessa e' o
                // que ha' atras). Comecar sempre no pai era um defeito: dava 1:1 em
                // todo botao branco-sobre-cor, que e' texto perfeitamente legivel.
                //
                // DEGRADE: `backgroundColor` de um elemento com `background:
                // linear-gradient(...)` e' transparente, e a busca subia direto para o
                // pai. No botao dourado da home isso dava texto escuro sobre a pagina
                // escura, 1,03:1 — reprovando um botao perfeitamente legivel. Aqui as
                // paradas de cor do degrade sao lidas e a media delas vale como fundo.
                const doDegrade = (cs) => {
                    const img = cs.backgroundImage || '';
                    if (!/gradient/.test(img)) return null;
                    const paradas = img.match(/rgba?\([^)]+\)/g);
                    if (!paradas || !paradas.length) return null;
                    const soma = [0, 0, 0];
                    paradas.forEach((c) => {
                        const [r, g, b] = rgba(c);
                        soma[0] += r; soma[1] += g; soma[2] += b;
                    });
                    const n = paradas.length;
                    return [soma[0] / n, soma[1] / n, soma[2] / n, 1];
                };

                const fundoDe = (el, incluirProprio) => {
                    let no = incluirProprio ? el : el.parentElement;
                    let pilha = [];
                    while (no) {
                        const cs = getComputedStyle(no);
                        const grad = doDegrade(cs);
                        if (grad) { pilha.push(grad); break; }
                        const c = cs.backgroundColor;
                        if (!transparente(c)) {
                            const p = rgba(c);
                            pilha.push(p);
                            if (p[3] >= 1) break;
                        }
                        no = no.parentElement;
                    }
                    let cor = [255, 255, 255];
                    for (let i = pilha.length - 1; i >= 0; i--) cor = sobre(pilha[i], cor);
                    return cor;
                };

                // ---- distancia perceptual (CIE76 em Lab)
                // POR QUE PRECISA: a razao da WCAG so' enxerga LUMINANCIA. O palco azul
                // (#e3fafc) sobre a secao (#f8f9fa) da' 1,03:1 e seria reprovado, mesmo
                // separando muito bem aos olhos — a diferenca dele e' de matiz, nao de
                // brilho. Medir so' por luminancia proibiria justamente a solucao que o
                // Rafael pediu ("um fundo azul claro"). Entao superficie passa por
                // luminancia OU por distancia de cor.
                const lab = ([r, g, b]) => {
                    const f = (v) => {
                        v /= 255;
                        return v > 0.04045 ? Math.pow((v + 0.055) / 1.055, 2.4) : v / 12.92;
                    };
                    const [R, G, B] = [f(r), f(g), f(b)];
                    const X = (R * 0.4124 + G * 0.3576 + B * 0.1805) / 0.95047;
                    const Y = (R * 0.2126 + G * 0.7152 + B * 0.0722);
                    const Z = (R * 0.0193 + G * 0.1192 + B * 0.9505) / 1.08883;
                    const g2 = (t) => t > 0.008856 ? Math.cbrt(t) : (7.787 * t + 16 / 116);
                    const [fx, fy, fz] = [g2(X), g2(Y), g2(Z)];
                    return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
                };
                const deltaE = (A, B) => {
                    const [a1, b1, c1] = lab(A), [a2_, b2, c2] = lab(B);
                    return Math.hypot(a1 - a2_, b1 - b2, c1 - c2);
                };

                const visivel = (el) => {
                    const r = el.getBoundingClientRect();
                    const cs = getComputedStyle(el);
                    return r.width > 1 && r.height > 1 && cs.visibility !== 'hidden'
                        && cs.display !== 'none' && Number(cs.opacity) > 0.05;
                };

                const marca = (el) => el.tagName.toLowerCase()
                    + (el.id ? '#' + el.id : '')
                    + (el.className && typeof el.className === 'string'
                        ? '.' + el.className.trim().split(/\s+/)[0] : '')
                    // Imagem quase nunca tem classe, entao "img" agrupava a pagina
                    // inteira num achado so' e escondia QUAL imagem falhou.
                    + (el.tagName === 'IMG' ? '[' + (el.getAttribute('src') || '').split('/').pop() + ']' : '');

                const out = [];
                const vistos = new Set();

                // ---- 1) TEXTO
                document.querySelectorAll('body *').forEach((el) => {
                    const proprio = [...el.childNodes]
                        .filter((n) => n.nodeType === 3).map((n) => n.textContent).join('').trim();
                    if (!proprio || !visivel(el)) return;

                    const cs = getComputedStyle(el);
                    const chave = 't|' + cs.color + '|' + marca(el);
                    if (vistos.has(chave)) return;
                    vistos.add(chave);

                    const fundo = fundoDe(el, true);
                    const cor = sobre(rgba(cs.color), fundo);
                    const px = parseFloat(cs.fontSize);
                    const peso = parseInt(cs.fontWeight, 10) || 400;
                    const grande = px >= 24 || (px >= 18.66 && peso >= 700);
                    const minimo = grande ? MIN_TEXTO_GRANDE : MIN_TEXTO;
                    const r = razao(cor, fundo);
                    if (r < minimo) {
                        out.push({
                            tipo: 'texto', marca: marca(el), razao: +r.toFixed(2),
                            minimo, amostra: proprio.slice(0, 40),
                        });
                    }
                });

                // ---- 2) SUPERFICIE
                // So' o que se apresenta como cartao/tela: tem fundo proprio ou e'
                // imagem/figura. Um <div> de layout sem fundo nao e' superficie.
                document.querySelectorAll('img, figure, .card, [class*="tela"], [class*="palco"], [class*="cartao"], section > div[style*="background"]').forEach((el) => {
                    if (!visivel(el)) return;
                    const cs = getComputedStyle(el);
                    const r0 = el.getBoundingClientRect();
                    if (r0.width < 60 || r0.height < 60) return;

                    const chave = 's|' + marca(el);
                    if (vistos.has(chave)) return;
                    vistos.add(chave);

                    const fundo = fundoDe(el, false);

                    // Cor da superficie: fundo declarado, ou o branco do PNG quando e'
                    // <img>. Imagem sem fundo declarado conta como o pixel medio? Nao:
                    // ler pixel de <img> local esbarra em canvas/CORS. As telas do app
                    // sao cartoes brancos, entao branco e' a leitura honesta e severa.
                    let sup = null;
                    const gradProprio = doDegrade(cs);
                    if (gradProprio) sup = sobre(gradProprio, fundo);
                    else if (!transparente(cs.backgroundColor)) sup = sobre(rgba(cs.backgroundColor), fundo);
                    else if (el.tagName === 'IMG') {
                        // Uma <img> sem fundo declarado so' conta como superficie se
                        // for PRINT DO APP, que e' um cartao branco. Foto nao e':
                        // ela tem cor propria e se separa sozinha. Ler o pixel real
                        // daria a resposta exata, mas canvas com file:// vem manchado
                        // e o teste tem que rodar offline. A regra por extensao vale
                        // aqui porque neste projeto ela e' verdadeira: print do app e'
                        // .png, foto de banco de imagem e' .jpg. Achado ao ver o
                        // conferidor reprovar petshop.jpg e lavajato.jpg, que sao as
                        // fotos do carrossel de segmentos.
                        const arq = (el.getAttribute('src') || '').toLowerCase();
                        if (/\.(jpg|jpeg|webp|avif)$/.test(arq)) return;
                        sup = [255, 255, 255];
                    }
                    if (!sup) return;

                    const larguraBorda = parseFloat(cs.borderTopWidth) || 0;
                    let rBorda = 0;
                    if (larguraBorda >= 1 && !transparente(cs.borderTopColor)) {
                        rBorda = razao(sobre(rgba(cs.borderTopColor), fundo), fundo);
                    }
                    const rFundo = razao(sup, fundo);
                    const separacao = Math.max(rFundo, rBorda);

                    let dE = deltaE(sup, fundo);
                    if (larguraBorda >= 1 && !transparente(cs.borderTopColor)) {
                        dE = Math.max(dE, deltaE(sobre(rgba(cs.borderTopColor), fundo), fundo));
                    }

                    if (separacao < MIN_SUPERFICIE && dE < MIN_DELTA_E) {
                        out.push({
                            tipo: 'superficie', marca: marca(el), razao: +separacao.toFixed(2),
                            minimo: MIN_SUPERFICIE,
                            amostra: `luz ${separacao.toFixed(2)}:1 e cor dE ${dE.toFixed(1)}`,
                        });
                    }
                });

                return out;
            }, { MIN_TEXTO, MIN_TEXTO_GRANDE, MIN_SUPERFICIE, MIN_DELTA_E });

            const rotulo = `${nome} @${largura}px`;
            if (achados.length) {
                falhas += achados.length;
                relatorio.push(`\n  REPROVOU  ${rotulo}`);
                achados.forEach((a) => relatorio.push(
                    `      ${a.tipo.padEnd(10)} ${String(a.razao).padStart(5)}:1 (min ${a.minimo})  ${a.marca}  "${a.amostra}"`));
            } else {
                relatorio.push(`  ok        ${rotulo}`);
            }
        }
        await ctx.close();
    }

    await browser.close();

    console.log('Contraste do site' + (noAr ? ' (no ar)' : ' (arquivos locais)'));
    console.log(relatorio.join('\n'));

    if (falhas) {
        console.log(`\n${falhas} problema(s). Regra em TAREFAS.md, "Regra de contraste".`);
        process.exit(1);
    }

    if (!noAr) {
        const hashes = {};
        for (const [nome, arquivo] of PAGINAS) hashes[nome] = sha(path.join(BASE, arquivo));
        fs.writeFileSync(MARCA, JSON.stringify(hashes, null, 2) + '\n');
        console.log(`\nTudo passou. Hashes gravados em ${path.relative(process.cwd(), MARCA)}.`);
    } else {
        console.log('\nTudo passou.');
    }
})();

#!/usr/bin/env python3
"""
Deixa as 4 telas do cliente com EXATAMENTE o mesmo tamanho, para a /agenda-global/.

POR QUE EXISTE (21/08/2026)
---------------------------
O `print_generico_cliente.js` recorta o cartao do assistente pela caixa natural dele
(`#book-appointment-wizard`), entao cada passo sai com uma altura diferente: 1808,
1944, 1584 e 2020. Com `width:100%; height:auto` na landing, isso vira quatro telas
de alturas diferentes lado a lado — a tira fica serrilhada, e foi o que o Rafael
reprovou. Na home o mesmo bloco parece certo porque la' as imagens sao MOCKUP,
desenhadas todas em 780x1688.

**Nao da' para resolver copiando as imagens da home.** Elas dizem "LOGO" e
"BARBEARIA" e mostram um agendamento inventado; as da /agenda-global/ sao print do
app de verdade. Trocar print real por mockup e' exatamente o defeito que a T164 e a
T186 corrigiram. O que se iguala aqui e' o TAMANHO, nao a origem da imagem.

O QUE ELE FAZ
-------------
1. Le o print bruto de `Instagram/video/saida/` quando existe (a fonte), ou o proprio
   arquivo publicado quando nao existe (a pasta e' gitignore e pode nao estar aqui).
2. Corta a sobra de cada arquivo pela regra em CORTES, que existe por um motivo so':
   o passo 2 termina 10 px depois de comecar a terceira fileira de horarios, e essa
   fatia de fileira lia como imagem cortada por engano.
3. Tira o rodape branco que ja' houver — e' isso que torna o script IDEMPOTENTE:
   rodar duas vezes seguidas devolve o mesmo arquivo, porque a etapa 4 so' repoe o
   que a etapa 3 tirou.
4. Preenche embaixo, com o branco do proprio cartao, ate todas terem a altura da mais
   alta. Preencher e nao cortar: cortar a mais alta comeria o botao CONFIRMAR, que e'
   o desfecho da sequencia.

Uso:
    python LandingPage/normalizar_telas.py
    python LandingPage/normalizar_telas.py --conferir   # so relata, nao escreve
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

BASE = Path(__file__).parent
RAIZ = BASE.parent
FONTE = RAIZ / "Instagram" / "video" / "saida"
DESTINO = BASE / "img"

TELAS = ["claro-tela-1", "claro-tela-2", "claro-tela-3", "claro-tela-4"]

# Corte por arquivo, em pixels a remover do rodape do print bruto. So' entra aqui o
# que o olho reprova; o resto e' zero de proposito.
#
# claro-tela-2: o print bruto tem 1944 e a terceira fileira de horarios comeca em
# 1934 — 10 px de fileira, que na pagina vira uma listra sem sentido. 1924 e' o fim
# da faixa branca depois da segunda fileira, medido linha a linha.
CORTES = {"claro-tela-2": 20}

# Acima disto a linha conta como "branco do cartao". Nao e' 255 exato porque o PNG
# vem de um screenshot com antialias.
BRANCO = 248


def linha_branca(px, largura, y):
    for x in range(0, largura, 3):
        r, g, b = px[x, y]
        if r < BRANCO or g < BRANCO or b < BRANCO:
            return False
    return True


def sem_rodape_branco(im):
    """Tira as linhas brancas do fim. E' o inverso exato do preenchimento."""
    largura, altura = im.size
    px = im.load()
    y = altura - 1
    while y >= 0 and linha_branca(px, largura, y):
        y -= 1
    return im if y == altura - 1 else im.crop((0, 0, largura, y + 1))


def carregar(nome):
    """A fonte e' o print bruto; o arquivo publicado e' o plano B."""
    bruto = FONTE / f"{nome}.png"
    publicado = DESTINO / f"{nome}.png"
    caminho = bruto if bruto.exists() else publicado
    if not caminho.exists():
        sys.exit(f"nao achei {nome}.png nem em {FONTE} nem em {DESTINO}")
    return Image.open(caminho).convert("RGB"), caminho


def main():
    p = argparse.ArgumentParser(description="Iguala a altura das 4 telas do cliente")
    p.add_argument("--conferir", action="store_true",
                   help="so relata o que faria, nao escreve arquivo nenhum")
    args = p.parse_args()

    preparadas = []
    for nome in TELAS:
        im, origem = carregar(nome)
        bruta = im.size
        corte = CORTES.get(nome, 0)
        if corte:
            im = im.crop((0, 0, im.width, im.height - corte))
        im = sem_rodape_branco(im)
        preparadas.append((nome, im, bruta, origem))

    larguras = {im.width for _, im, _, _ in preparadas}
    if len(larguras) != 1:
        sys.exit(f"as telas tem larguras diferentes ({sorted(larguras)}) — "
                 "preencher embaixo nao resolve isso, refaca os prints")

    alvo = max(im.height for _, im, _, _ in preparadas)
    print(f"Altura alvo: {alvo}px (a mais alta depois do corte)\n")

    for nome, im, bruta, origem in preparadas:
        falta = alvo - im.height
        destino = DESTINO / f"{nome}.png"
        de_onde = "saida" if FONTE in origem.parents else "img"
        print(f"  {nome}: {bruta[0]}x{bruta[1]} ({de_onde}) -> {im.width}x{alvo}"
              f"  [preenche {falta}px]")
        if args.conferir:
            continue
        if falta:
            folha = Image.new("RGB", (im.width, alvo), (255, 255, 255))
            folha.paste(im, (0, 0))
            im = folha
        im.save(destino, optimize=True)

    if args.conferir:
        print("\n--conferir: nenhum arquivo escrito.")
    else:
        print(f"\n{len(TELAS)} telas gravadas em {DESTINO} com {im.width}x{alvo}.")
        print("Lembre de acertar width/height no <img> da /agenda-global/.")


if __name__ == "__main__":
    main()

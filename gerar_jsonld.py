#!/usr/bin/env python3
"""
Gera e (re)insere o JSON-LD das paginas do Horario Cheio.

Por que existe: o Google exige que o schema seja IDENTICO ao texto visivel. Digitar
as perguntas do FAQ a mao garante divergencia na primeira edicao da pagina, entao
elas sao extraidas do proprio HTML.

Uso:
    python gerar_jsonld.py

E idempotente: se ja houver um bloco JSON-LD gerado por aqui, ele e' SUBSTITUIDO
(delimitado pelos marcadores abaixo), nunca duplicado.
"""

import re
import sys
import json
from pathlib import Path

BASE = Path(__file__).parent
SITE = "https://horariocheio.com.br/"

INICIO = "<!-- JSONLD:INICIO (gerado por gerar_jsonld.py - nao editar a mao) -->"
FIM = "<!-- JSONLD:FIM -->"

ORG = {
    "@type": "Organization", "@id": SITE + "#org", "name": "Horário Cheio",
    "url": SITE, "logo": SITE + "img/logo.png", "telephone": "+55-11-93935-7759",
    "description": "Sistema de agendamento online para barbearias, com a marca da própria barbearia.",
    "areaServed": [{"@type": "City", "name": "Guarulhos"},
                   {"@type": "State", "name": "São Paulo"},
                   {"@type": "Country", "name": "Brasil"}],
    "address": {"@type": "PostalAddress", "addressLocality": "Guarulhos",
                "addressRegion": "SP", "addressCountry": "BR"},
    "contactPoint": {"@type": "ContactPoint", "contactType": "vendas",
                     "telephone": "+55-11-93935-7759", "availableLanguage": "Portuguese"},
}

APP = {
    "@type": "SoftwareApplication", "@id": SITE + "#app", "name": "Horário Cheio",
    "applicationCategory": "BusinessApplication",
    "applicationSubCategory": "Agendamento online",
    "operatingSystem": "Web (navegador, sem instalação)",
    "url": SITE, "inLanguage": "pt-BR", "publisher": {"@id": SITE + "#org"},
    "description": ("App de agendamento online para barbearias. O cliente escolhe serviço, "
                    "barbeiro e horário por um link com a marca da barbearia, sem baixar "
                    "aplicativo e sem cadastro."),
    "featureList": ["Agenda individual por barbeiro",
                    "Férias, folga e almoço por profissional",
                    "Bloqueio de dia da barbearia inteira",
                    "Contatos do dia com mensagem pronta",
                    "Confirmação e remarcação pelo WhatsApp",
                    "Cadastro de clientes exportável",
                    "Marca, logo e cor da própria barbearia"],
    "offers": [
        {"@type": "Offer", "name": "Essencial", "price": "49.90", "priceCurrency": "BRL",
         "category": "Assinatura mensal", "url": SITE,
         "availability": "https://schema.org/InStock",
         "description": ("App completo com a marca da barbearia, barbeiros ilimitados, "
                         "instalação grátis e 14 dias grátis para testar.")},
        {"@type": "Offer", "name": "Completo", "price": "99.90", "priceCurrency": "BRL",
         "category": "Assinatura mensal", "url": SITE,
         "availability": "https://schema.org/InStock",
         "description": ("Tudo do Essencial mais domínio próprio registrado e pago, "
                         "e montagem de logo e cores.")}],
}


# Paginas de segmento e a de comparacao: todas seguem o mesmo formato
# (WebPage + FAQPage). So a landing tem Organization, WebSite e SoftwareApplication,
# que sao do site inteiro e nao podem ser repetidos em cada pagina.
# Para acrescentar um segmento novo: uma entrada aqui e a pagina em <pasta>/index.html.
SECUNDARIAS = {
    "comparar": {
        "pasta": "comparar",
        "nome": "AppBarber, Booksy ou Horário Cheio: comparação de preços",
        "descricao": ("Comparação de preços entre AppBarber, Booksy e Horário Cheio "
                      "para barbearias, com fonte e data de consulta."),
    },
    # A pasta virou "agenda-global" em 19/08/2026 e este dicionario ainda nao foi
    # acertado — e' a T171. Nome e descricao ja' foram atualizados aqui em
    # 20/08/2026 para bater com o que esta no <head> da pagina, para que o conserto
    # da T171 nao reverta o JSON-LD que a pagina serve hoje.
    "como-funciona": {
        "pasta": "como-funciona",
        "nome": "Agenda Global: uma agenda para barbearia, manicure, estética, consultório e mais",
        "descricao": ("Agendamento online para quem trabalha com hora marcada: o cliente "
                      "escolhe o serviço, o profissional e o horário disponível, e o "
                      "agendamento cai direto na agenda do negócio. Barbearias, salões, "
                      "manicures, estética, massagem, tatuagem, consultórios e outros "
                      "serviços com horário marcado."),
    },
    "manicure": {
        "pasta": "manicure",
        "nome": "Sistema de agendamento para manicure e nail designer",
        "descricao": ("Agenda online para manicure, pedicure e nail designer com a marca "
                      "do próprio estúdio: a cliente marca pelo link, cada serviço com a "
                      "duração real, sem cobrança por profissional."),
    },
    "estetica": {
        "pasta": "clinica-estetica",
        "nome": "Sistema de agendamento para clínica de estética",
        "descricao": ("Agenda online para clínica de estética e esteticista com a marca da "
                      "própria clínica: agenda por profissional, link no lugar da conversa "
                      "do Instagram, preço da clínica e não por profissional."),
    },
}


def extrair_faq(html):
    """Le os <details><summary>pergunta</summary><p>resposta</p></details> da pagina."""
    blocos = re.findall(
        r"<details>\s*<summary>(.*?)</summary>\s*<p>(.*?)</p>\s*</details>", html, flags=re.S)
    limpa = lambda s: re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", s)).strip()
    return [{"@type": "Question", "name": limpa(q),
             "acceptedAnswer": {"@type": "Answer", "text": limpa(a)}} for q, a in blocos]


def montar(pagina, html):
    faq = extrair_faq(html)
    if pagina == "landing":
        grafo = [ORG,
                 {"@type": "WebSite", "@id": SITE + "#site", "url": SITE,
                  "name": "Horário Cheio", "inLanguage": "pt-BR",
                  "publisher": {"@id": SITE + "#org"}},
                 APP,
                 {"@type": "FAQPage", "@id": SITE + "#faq", "mainEntity": faq}]
    else:
        meta = SECUNDARIAS[pagina]
        url = SITE + meta["pasta"] + "/"
        grafo = [
            {"@type": "WebPage", "@id": url, "url": url,
             "name": meta["nome"],
             "inLanguage": "pt-BR", "isPartOf": {"@id": SITE + "#site"},
             "publisher": {"@id": SITE + "#org"},
             "about": {"@id": SITE + "#app"},
             # datePublished honesto: todas nasceram em 16/08/2026 e essa data nao
             # muda mais. dateModified sobe a cada reescrita de verdade — data falsa
             # e' sinal de spam, e data velha desperdica a reescrita.
             # 17/08/2026: as tres foram redesenhadas (Open Props, fundo claro,
             # secao nova do painel), entao o dateModified andou junto.
             "datePublished": "2026-08-16", "dateModified": "2026-08-17",
             "description": meta["descricao"]},
            {"@type": "FAQPage", "@id": url + "#faq", "mainEntity": faq},
        ]
    return {"@context": "https://schema.org", "@graph": grafo}


PAGINAS = {"landing": BASE / "index.html"}
for _nome, _meta in SECUNDARIAS.items():
    PAGINAS[_nome] = BASE / _meta["pasta"] / "index.html"

for nome, caminho in PAGINAS.items():
    if not caminho.exists():
        sys.exit(f"nao achei {caminho}")

    html = caminho.read_text(encoding="utf-8")
    dados = montar(nome, html)
    n_faq = len(dados["@graph"][-1]["mainEntity"])
    if n_faq == 0:
        sys.exit(f"{nome}: nenhuma pergunta encontrada — o HTML do FAQ mudou de formato?")

    bloco = (INICIO + '\n<script type="application/ld+json">\n'
             + json.dumps(dados, ensure_ascii=False, indent=2)
             + "\n</script>\n" + FIM)

    if INICIO in html:
        html = re.sub(re.escape(INICIO) + r".*?" + re.escape(FIM), lambda m: bloco,
                      html, flags=re.S)
        acao = "substituido"
    else:
        # remove um bloco anterior sem marcador (o primeiro, inserido em 16/08/2026)
        html = re.sub(r'<script type="application/ld\+json">.*?</script>\s*', "",
                      html, flags=re.S)
        html = html.replace("</head>", bloco + "\n\n</head>", 1)
        acao = "inserido"

    caminho.write_text(html, encoding="utf-8", newline="")
    print(f"{nome:9} {acao:12} {n_faq} perguntas  ->  {caminho.name}")

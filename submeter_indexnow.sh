#!/bin/sh
# Submete as URLs da landing ao IndexNow.
#
# Criado em 17/08/2026. Motivo: o dominio tem dias de vida e nao estava em indice
# nenhum. O Search Console resolve o lado do Google e depende de login do Rafael;
# o IndexNow resolve o lado do Bing/Yandex e NAO precisa de conta — a prova de
# posse e' a chave hospedada na raiz do site.
#
# Por que o Bing importa mais do que o tamanho dele sugere: a busca do ChatGPT se
# apoia no indice do Bing. Quem quer aparecer em resposta de IA passa por ali.
#
# O Google NAO participa do IndexNow. Para ele nao existe atalho: e' o Search
# Console (T66), e so' o Rafael pode fazer.
#
# Rodar depois de toda publicacao de conteudo:
#   sh submeter_indexnow.sh
set -e

HOST="horariocheio.com.br"
CHAVE="c929c8a157d8a1049c251a6aab441e6c"

# A chave PRECISA estar respondendo antes de submeter: sem isso o endpoint aceita
# o pedido e descarta depois, em silencio — falha que nao aparece no codigo HTTP.
if [ "$(curl -s -o /dev/null -w '%{http_code}' "https://$HOST/$CHAVE.txt")" != "200" ]; then
  echo "ERRO: https://$HOST/$CHAVE.txt nao responde 200. Nao submeti nada." >&2
  exit 1
fi

# A /demo/ fica de fora de proposito: ela esta em Disallow no robots.txt.
# Submeter URL bloqueada e' pedido contraditorio e queima confianca do dominio.
CORPO=$(cat <<JSON
{
  "host": "$HOST",
  "key": "$CHAVE",
  "keyLocation": "https://$HOST/$CHAVE.txt",
  "urlList": [
    "https://$HOST/",
    "https://$HOST/como-funciona/",
    "https://$HOST/manicure/",
    "https://$HOST/clinica-estetica/",
    "https://$HOST/comparar/"
  ]
}
JSON
)

# O codigo de saida tem que refletir o resultado. Um script de submissao que
# imprime erro e sai 0 e' a mesma armadilha da T101 no envio para o GitHub: voce
# acredita que submeteu e nao submeteu.
ERROS=0
for ENDPOINT in "https://api.indexnow.org/indexnow" "https://www.bing.com/indexnow"; do
  COD=$(curl -s -o /tmp/indexnow.out -w '%{http_code}' -X POST "$ENDPOINT" \
        -H "Content-Type: application/json; charset=utf-8" -d "$CORPO")
  # 200 = aceito e processado. 202 = aceito, chave ainda sendo validada.
  # 422 = URL nao casa com o host. 403 = chave invalida.
  case "$COD" in
    200|202) echo "OK    $ENDPOINT -> $COD" ;;
    *)       echo "FALHA $ENDPOINT -> $COD" >&2; ERROS=$((ERROS + 1)) ;;
  esac
  if [ -s /tmp/indexnow.out ]; then echo "      resposta: $(cat /tmp/indexnow.out)"; fi
done

rm -f /tmp/indexnow.out
if [ "$ERROS" -gt 0 ]; then
  echo "" >&2
  echo "$ERROS endpoint(s) recusaram. NAO considere submetido." >&2
  exit 1
fi
echo ""
echo "5 URLs submetidas ao IndexNow (Bing e Yandex). O Google nao participa - ver T66."

# Baixa uma foto de cada segmento, do Pexels, para o carrossel da /agenda-global/.
#
# Criado em 20/08/2026 (T183). A pagina lista 17 segmentos; texto sozinho nao diz
# ao visitante "isto e' para mim" tao rapido quanto uma foto da atividade dele.
#
# Le a chave de PEXELS_API_KEY - nunca de arquivo do projeto, mesmo padrao do
# GOOGLE_PLACES_API_KEY e do baixar_fotos.ps1 do Instagram.
#
# ORIENTACAO LANDSCAPE, e nao portrait como no Instagram: aqui a foto entra num
# cartao largo e baixo, e foto em pe cortada para 16:9 perde justamente o meio,
# que e' onde esta a atividade.
#
# REGRA DE USO (a mesma do Instagram/conteudo/baixar_fotos.ps1):
# rosto PODE - a licenca do Pexels permite uso comercial. O que nao pode e'
# apresentar a pessoa da foto como CLIENTE do Horario Cheio. Aqui ela ilustra o
# SEGMENTO, nao um depoimento.
#
# E TODA foto tem que ser olhada antes de entrar na pagina, por outro motivo:
# banco de imagem devolve marca de terceiro sem avisar.
#
# Uso:
#   .\baixar_fotos_segmentos.ps1                 # baixa o que faltar
#   .\baixar_fotos_segmentos.ps1 -Id manicure    # so um segmento
#   .\baixar_fotos_segmentos.ps1 -Forcar         # rebaixa mesmo o que existe
#   .\baixar_fotos_segmentos.ps1 -Id manicure -Pular 1   # a proxima candidata

param(
    [string]$Id = "",
    [switch]$Forcar,
    [int]$Pular = -1
)

$ErrorActionPreference = 'Stop'
$dir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$saida = Join-Path $dir 'img\segmentos'

$chave = $env:PEXELS_API_KEY
if (-not $chave) { $chave = [Environment]::GetEnvironmentVariable('PEXELS_API_KEY', 'User') }
if (-not $chave) {
    Write-Host "ERRO: variavel de ambiente PEXELS_API_KEY nao definida."
    Write-Host '  Defina uma vez com:  setx PEXELS_API_KEY "sua-chave"'
    exit 1
}

# A busca e' em INGLES de proposito: o acervo do Pexels e' indexado em ingles, e
# "manicure" em portugues devolve um terco dos resultados de "manicure nails".
#
# O 'pular' diz QUAL candidata do resultado usar, e existe porque a escolha e'
# curadoria, nao sorte: as tres que estao em 2 e 3 tiveram a primeira candidata
# recusada na conferencia de 20/08/2026 — manicure devolveu um vidro de esmalte em
# cima da mesa, sem unha nenhuma; professor devolveu o que parecia reuniao de
# escritorio; e lava-jato veio com uma placa grande em vietnamita. O lava-jato
# rodou quatro candidatas: as outras tres ou repetiam uma porta de carro com
# espuma, que depois do corte 4:3 nao se reconhece como lava-jato, ou traziam
# letreiro estrangeiro legivel ao fundo. Guardar isso
# aqui, e nao num parametro de linha de comando, e' o que faz rodar de novo com
# -Forcar devolver as MESMAS fotos.
$segmentos = @(
    @{ id = 'barbearia';   pular = 0; busca = 'barber shop haircut client' },
    @{ id = 'salao';       pular = 0; busca = 'hairdresser salon washing hair' },
    @{ id = 'manicure';    pular = 2; busca = 'manicure nail polish hands' },
    @{ id = 'cilios';      pular = 0; busca = 'eyelash extension technician' },
    @{ id = 'maquiagem';   pular = 0; busca = 'makeup artist applying makeup' },
    @{ id = 'estetica';    pular = 0; busca = 'facial treatment esthetician' },
    @{ id = 'depilacao';   pular = 0; busca = 'waxing hair removal salon' },
    @{ id = 'massagem';    pular = 0; busca = 'massage therapist back massage' },
    @{ id = 'podologia';   pular = 0; busca = 'pedicure foot treatment' },
    @{ id = 'fisioterapia';pular = 0; busca = 'physical therapy rehabilitation' },
    @{ id = 'personal';    pular = 0; busca = 'personal trainer gym coaching' },
    @{ id = 'dentista';    pular = 0; busca = 'dentist dental clinic patient' },
    @{ id = 'medico';      pular = 0; busca = 'doctor consultation patient office' },
    @{ id = 'psicologo';   pular = 0; busca = 'therapy session counseling talking' },
    @{ id = 'petshop';     pular = 0; busca = 'dog grooming pet salon' },
    @{ id = 'professor';   pular = 3; busca = 'private tutor teaching student' },
    @{ id = 'lavajato';    pular = 1; busca = 'car wash washing vehicle' },
    # Tatuagem nao esta na lista do agende-me, que foi a referencia; esta aqui
    # porque a /agenda-global/ ja atendia o segmento antes e tirar seria perder
    # alcance para copiar a lista de outro.
    @{ id = 'tatuagem';    pular = 0; busca = 'tattoo artist tattooing arm' }
)

# A lista inteira fica guardada ANTES do filtro. E' ela que manda na gravacao do
# creditos.json la embaixo: percorrer a lista filtrada apagaria do arquivo os 16
# segmentos que a rodada com -Id nem tocou — que e' exatamente como o arquivo foi
# de 17 entradas para 2 em 20/08/2026.
$todos = $segmentos

if ($Id) {
    $segmentos = @($segmentos | Where-Object { $_.id -eq $Id })
    if (-not $segmentos) { Write-Host "ERRO: nenhum segmento com id '$Id'"; exit 1 }
}

New-Item -ItemType Directory -Force $saida | Out-Null

# O ffmpeg normaliza toda foto para 800x600 depois de baixar. Sem isso o acervo
# sai desigual: o Pexels devolve de 1.200x800 a 5.000x3.300 no mesmo 'large', e em
# 20/08/2026 a manicure veio com 729 KB contra 43 KB da barbearia — 17x mais peso
# para o mesmo cartao de 300px na tela. Normalizadas, as 18 somam 730 KB.
# Ele tambem RECORTA para 4:3, que e' a proporcao do cartao: deixar o navegador
# cortar com object-fit desperdicia download.
$ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ffmpeg) {
    $ffmpeg = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0-full_build\bin\ffmpeg.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $ffmpeg) {
    Write-Host "ERRO: ffmpeg nao encontrado. Sem ele as fotos ficam com tamanho e peso"
    Write-Host "      desiguais, que e' o defeito que esta normalizacao existe para evitar."
    exit 1
}

$arqCred = Join-Path $saida 'creditos.json'

# So' o que ESTA rodada baixou. O arquivo antigo e' lido la embaixo, na hora de
# gravar, e nao aqui: manter o acervo inteiro numa variavel durante o download foi
# o que corrompeu o creditos.json duas vezes em 20/08/2026 (17 entradas viraram 2,
# depois 18 viraram 1). Ler imediatamente antes de escrever fecha a janela.
$novos = @{}

$baixadas = 0
$falhas   = 0

foreach ($s in $segmentos) {
    $arq = Join-Path $saida "$($s.id).jpg"
    if ((Test-Path $arq) -and -not $Forcar) { Write-Host "ja existe: $($s.id).jpg"; continue }

    # per_page maior que o necessario para o -Pular ter de onde escolher quando a
    # primeira candidata vier com marca de terceiro ou nao disser a atividade.
    $url = "https://api.pexels.com/v1/search?query=$([uri]::EscapeDataString($s.busca))&per_page=8&orientation=landscape&size=medium"

    try {
        $r = Invoke-RestMethod -Uri $url -Headers @{ Authorization = $chave } -TimeoutSec 30
    } catch {
        Write-Host "  FALHOU $($s.id): $($_.Exception.Message)"
        $falhas++
        continue
    }

    # -Pular na linha de comando so' existe para EXPERIMENTAR outra candidata; o
    # valor que vale no dia a dia e' o da tabela acima.
    $salto = if ($Pular -ge 0) { $Pular } else { [int]$s.pular }
    $f = $r.photos | Select-Object -Skip $salto -First 1
    if (-not $f) { Write-Host "  SEM RESULTADO: $($s.id) ($($s.busca))"; $falhas++; continue }

    $bruto = Join-Path $saida "_bruto_$($s.id).jpg"
    Invoke-WebRequest -Uri $f.src.large -OutFile $bruto -TimeoutSec 60 | Out-Null

    & $ffmpeg -y -loglevel error -i $bruto `
        -vf "scale=800:600:force_original_aspect_ratio=increase,crop=800:600" `
        -q:v 4 $arq
    Remove-Item $bruto -Force

    if (-not (Test-Path $arq)) { Write-Host "  FALHOU o corte: $($s.id)"; $falhas++; continue }

    # Um credito por SEGMENTO: rebaixar com -Forcar substitui a linha em vez de
    # empilhar uma segunda, senao o creditos.json passa a mentir sobre qual foto
    # esta na pagina.
    $novos[[string]$s.id] = [pscustomobject]@{
        segmento  = $s.id
        arquivo   = "$($s.id).jpg"
        busca     = $s.busca
        candidata = $salto
        autor     = $f.photographer
        autor_url = $f.photographer_url
        foto_url  = $f.url
        baixada   = (Get-Date -Format 'yyyy-MM-dd')
    }
    Write-Host "OK: $($s.id).jpg  ($($f.photographer))"
    $baixadas++
}

# O creditos.json so' e' reescrito na RODADA COMPLETA.
#
# Por que nao no -Id: tentei duas vezes fazer a rodada parcial mesclar o que ja'
# estava no arquivo, e as duas versoes corromperam o acervo em 20/08/2026 — 17
# entradas viraram 2, depois 18 viraram 1. A causa e' o ConvertFrom-Json do
# PowerShell 5.1 dentro deste script: lendo o MESMO arquivo de 18 objetos, no
# console ele devolve 18 e aqui devolve 1. Nao encontrei a razao, e o arquivo que
# diz de onde vem cada foto nao e' lugar para conviver com bug intermitente.
#
# Entao o -Id ficou sendo o que ele e' de fato: um jeito de EXPERIMENTAR outra
# candidata. Gostou? grave o numero no campo 'pular' da tabela la em cima e rode
# uma vez com -Forcar. O acervo inteiro e as fotos saem iguais, porque a escolha
# de cada uma esta na tabela e nao no comando.
if ($Id) {
    Write-Host ""
    Write-Host "creditos.json NAO foi tocado: rodada com -Id nao reescreve o acervo."
    Write-Host "Se a foto nova for a boa, grave o numero do -Pular no campo 'pular'"
    Write-Host "da tabela deste script e rode uma vez:  .\baixar_fotos_segmentos.ps1 -Forcar"
    exit 0
}

$creditos = $novos

# -InputObject e nao pipe: pelo pipe o ConvertTo-Json do PS 5.1 serializa o
# INVOLUCRO do array ({"value":[...],"Count":n}) em vez dos itens.
# Gravado na ordem do $todos, e nao na ordem do hashtable: assim o arquivo sai
# igual toda vez e o diff do Git mostra so' o que mudou de verdade.
$ordenados = @()
foreach ($s in $todos) {
    if ($creditos.ContainsKey([string]$s.id)) { $ordenados += $creditos[[string]$s.id] }
}
ConvertTo-Json -InputObject $ordenados -Depth 3 |
    Set-Content $arqCred -Encoding UTF8

Write-Host ""
Write-Host "baixadas: $baixadas   falhas: $falhas   no acervo: $($ordenados.Count)"
Write-Host ""
Write-Host "OLHE UMA POR UMA antes de publicar: marca de terceiro na foto, e"
Write-Host "atividade que nao se reconhece de relance, sao os dois motivos de troca."
Write-Host "  Experimentar outra:  .\baixar_fotos_segmentos.ps1 -Id <id> -Forcar -Pular 1"
Write-Host "  Gostou? grave o numero no campo 'pular' da tabela deste script."
if ($falhas -gt 0) { exit 1 }

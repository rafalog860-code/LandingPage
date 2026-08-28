# Gera os PNGs do logo a partir dos SVGs mestres em img/.
#
# Criado em 27/08/2026, quando a marca trocou a tesoura de "AGENDA BARBEIRO" pelo
# relogio verde (T13 e T105). Os mestres sao img/logo.svg (versao cheia, 32px para
# cima) e img/favicon.svg (versao engrossada, 28px para baixo).
#
# ATENCAO: este arquivo e' ASCII puro DE PROPOSITO. O PowerShell 5.1 le .ps1 sem BOM
# como Windows-1252 e corrompe acento (ver Instagram/conteudo/gerar.ps1). Todo texto
# acentuado que entra no PNG vai como entidade HTML (&#243;), nunca como caractere.
#
# Uso:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\gerar_logo.ps1

$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$img = Join-Path $dir 'img'
$tmp = Join-Path $env:TEMP 'hc-logo-build'
New-Item -ItemType Directory -Force $tmp | Out-Null

$edge = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { Write-Host "ERRO: Edge nao encontrado"; exit 1 }

$cheia = Get-Content (Join-Path $img 'logo.svg') -Raw
$grossa = Get-Content (Join-Path $img 'favicon.svg') -Raw

function Render($nome, $largura, $altura, $corpo, $transparente) {
    $html = @"
<!doctype html><meta charset="utf-8"><style>
html,body{margin:0;padding:0;width:${largura}px;height:${altura}px;overflow:hidden}
body{display:flex;align-items:center;justify-content:center;
     font-family:Georgia,'Times New Roman',serif}
svg{display:block}
</style>$corpo
"@
    $arqHtml = Join-Path $tmp "$nome.html"
    [System.IO.File]::WriteAllText($arqHtml, $html, (New-Object System.Text.UTF8Encoding $false))
    $saida = Join-Path $img "$nome.png"
    if (Test-Path $saida) { Remove-Item $saida -Force }
    $url = 'file:///' + $arqHtml.Replace([char]92, [char]47)
    $args = @("--headless", "--disable-gpu", "--hide-scrollbars",
              "--window-size=$largura,$altura", "--screenshot=$saida", $url)
    if ($transparente) { $args = @("--default-background-color=00000000") + $args }
    Start-Process -FilePath $edge -ArgumentList $args -Wait -NoNewWindow
    if (Test-Path $saida) { Write-Host ("  ok  {0}.png  {1}x{2}" -f $nome, $largura, $altura) }
    else { Write-Host ("  FALHOU  {0}.png" -f $nome) }
}

# 1. og:image do WhatsApp. Nome novo de proposito: o WhatsApp guarda cache por URL,
#    e trocar o arquivo forcaria o card antigo a continuar aparecendo.
$svgOg = $cheia -replace '<svg ', '<svg width="150" height="150" '
$og = @"
<div style="background:#0d0d0d;width:1200px;height:630px;display:flex;
            flex-direction:column;align-items:center;justify-content:center;gap:34px">
  <div style="display:flex;align-items:center;gap:30px">
    $svgOg
    <div style="color:#00a651;font-size:56px;letter-spacing:.14em;
                text-transform:uppercase;line-height:1.22">Hor&#225;rio<br>Cheio</div>
  </div>
  <div style="width:230px;height:1px;background:#00a651;opacity:.4"></div>
  <div style="color:#c9c4b8;font-size:29px;line-height:1.5;text-align:center;max-width:900px">
    Agenda online com a sua marca, e consultoria para faturar mais
  </div>
</div>
"@
Render 'og-home' 1200 630 $og $false

# 2. Logo quadrado. E' o schema.org/logo e o retrato do azulejo escuro.
#    NOME NOVO (.v2) e' obrigatorio: o servidor manda Cache-Control de 7 dias sem
#    ETag, e ?v= nao fura a CDN da Hostinger. Reaproveitar 'logo.png' deixaria a
#    marca antiga servida por ate uma semana. Ver a skill publicar.
$svgQ = $cheia -replace '<svg ', '<svg width="340" height="340" '
Render 'logo.v2' 512 512 "<div style=""background:#0d0d0d;width:512px;height:512px;display:flex;align-items:center;justify-content:center"">$svgQ</div>" $false

# 3. Icone da tela de inicio. Fundo e' OBRIGATORIO aqui: sobre papel de parede o
#    transparente cai para 1,09:1, e o iOS preenche de preto por conta propria.
$svgA = $grossa -replace '<svg ', '<svg width="122" height="122" '
Render 'apple-touch-icon' 180 180 "<div style=""background:#0d0d0d;width:180px;height:180px;display:flex;align-items:center;justify-content:center"">$svgA</div>" $false

# 4. Favicon PNG de reserva, para navegador que ignora favicon SVG. Renderiza em 256
#    e o reduz depois, que sai mais limpo do que renderizar direto em 32.
$svgF = $grossa -replace '<svg ', '<svg width="256" height="256" '
Render 'favicon-256' 256 256 $svgF $true

Write-Host "PNGs em $img"

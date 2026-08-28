# Horário Cheio — site

Página única em HTML puro. Sem build, sem framework, sem CDN: o `index.html` traz o CSS
dentro dele e as imagens são locais. Abrir o arquivo no navegador já mostra o resultado
final — o que está no ar é exatamente isto.

> **Javascript, desde 21/08/2026.** A home e a `/diferencial-dos-concorrentes/` tinham
> zero código executável até essa data. Entrou em cada uma um `<script>` de 20 linhas, no
> fim do arquivo, que faz uma coisa só: o **opt-in de WhatsApp** (T194). Com a caixa
> marcada ele acrescenta a frase de autorização ao `?text=` de todos os links `wa.me` da
> página; **desmarcada, o href é byte a byte o original**, e é assim que ele nasce. Isso é
> proposital, para o caminho de conversão medido da home não mudar para quem ignorar a
> caixa. A `/agenda-global/` já tinha script próprio (o carrossel) e ganhou um segundo
> bloco. Continua sem build e sem framework.

Publicada na **Hostinger** em <https://horariocheio.com.br/>, desde 15/08/2026.

Deploy: empacotar `index.html`, `img/` e `.nojekyll` e extrair em
`~/domains/horariocheio.com.br/public_html/` — a mesma conta e a mesma chave SSH do app.
A pasta tem também o `demo/` (a instância de demonstração) e o `default.php` da Hostinger,
que fica sem uso porque o `index.html` tem precedência.

> O endereço anterior era o GitHub Pages (`rafalog860-code.github.io/LandingPage/`).
> Saiu de cena junto com o domínio próprio; se o repositório recortado ainda existir, ele
> agora serve uma versão velha.

## Arquivos

| Arquivo | O que é |
|---|---|
| `index.html` | A página inteira |
| `img/tela-1..4.png` | As quatro telas do app (os passos do agendamento) |
| `img/marca-azul.png`, `img/marca-terracota.png` | A mesma tela com outra marca — a prova visual do white-label |
| `img/logo.png` | Logo, favicon e imagem do card de link |
| `.nojekyll` | Resíduo do GitHub Pages. Inofensivo na Hostinger; mantido caso o Pages volte a ser usado como espelho |
| `privacidade/index.html` | Política de privacidade **do site** (21/08/2026). Não confundir com o `Juridico/aviso-privacidade.md`, que é da página de agendamento da barbearia: lá o controlador é a barbearia e a base legal é execução de contrato; aqui é o Horário Cheio, e o opt-in de WhatsApp roda por consentimento |
| `img/segmentos/` | As 18 fotos do carrossel da `/agenda-global/`, 800x600, com `creditos.json` dizendo o autor de cada uma |
| `baixar_fotos_segmentos.ps1` | Baixa e normaliza essas 18 fotos (Pexels + ffmpeg). A escolha de qual candidata usar está na tabela dentro do script, não no comando — é o que faz rodar de novo devolver as mesmas fotos |

## Se o endereço mudar

Ao entrar um domínio próprio, **três linhas** no `<head>` do `index.html`:
`canonical`, `og:url` e `og:image`. Elas são absolutas de propósito — o robô do WhatsApp
e do Instagram não resolve caminho relativo, e sem isso o card do link sai sem imagem.

## De onde vem este repositório

O original mora em `C:\Agentes\AgendaHorario\LandingPage`, dentro do repositório do
projeto inteiro. Aqui chega um recorte feito por `git subtree split` — o mesmo mecanismo
usado no repositório do app. Editar aqui direto faz o conteúdo divergir da origem.

# Agenda Barbeiro — site

Página única em HTML puro. Sem build, sem framework, sem CDN: o `index.html` traz o CSS
dentro dele e as imagens são locais. Abrir o arquivo no navegador já mostra o resultado
final — o que está no ar é exatamente isto.

Publicado pelo **GitHub Pages** em <https://rafalog860-code.github.io/>.

## Arquivos

| Arquivo | O que é |
|---|---|
| `index.html` | A página inteira |
| `img/tela-1..4.png` | As quatro telas do app (os passos do agendamento) |
| `img/marca-azul.png`, `img/marca-terracota.png` | A mesma tela com outra marca — a prova visual do white-label |
| `img/logo.png` | Logo, favicon e imagem do card de link |
| `.nojekyll` | Desliga o Jekyll do GitHub Pages: o site é servido como está |

## Se o endereço mudar

Ao entrar um domínio próprio, **três linhas** no `<head>` do `index.html`:
`canonical`, `og:url` e `og:image`. Elas são absolutas de propósito — o robô do WhatsApp
e do Instagram não resolve caminho relativo, e sem isso o card do link sai sem imagem.

## De onde vem este repositório

O original mora em `C:\Agentes\AgendaHorario\LandingPage`, dentro do repositório do
projeto inteiro. Aqui chega um recorte feito por `git subtree split` — o mesmo mecanismo
usado no repositório do app. Editar aqui direto faz o conteúdo divergir da origem.

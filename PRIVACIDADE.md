# Política de Privacidade — Livro-Caixa

_Última atualização: 25 de novembro de 2026_

O Livro-Caixa é um app pessoal de finanças domésticas, de código aberto, feito para uso de uma
família. Esta política explica quais dados o app usa e para onde eles vão.

## Onde ficam os seus dados

- Tudo o que você lança (entradas, gastos, contas, categorias, listas de compras, ajustes) fica
  guardado **no próprio aparelho**, num banco de dados local.
- O app **não tem servidor próprio**. O desenvolvedor **não recebe, não vê e não guarda** nenhum
  dado seu.
- O app **não usa** propaganda, rastreamento, análise de uso nem serviços de terceiros para coletar
  informações.

## Sincronização com o Google Drive (opcional)

Se você ligar a sincronização, o app usa a sua conta Google para guardar uma cópia dos dados no
**seu próprio Google Drive**, na pasta oculta de dados do app (`appDataFolder`).

- A única permissão pedida é `https://www.googleapis.com/auth/drive.appdata`. Com ela, o app só
  enxerga os arquivos que ele mesmo criou nessa pasta oculta; **não tem acesso** aos seus outros
  arquivos, fotos, e-mails ou contatos.
- Antes de sair do aparelho, os dados são **criptografados** (AES-256-GCM) com a "senha da casa"
  que você escolhe. Sem essa senha, ninguém consegue ler o conteúdo, nem o Google, nem o
  desenvolvedor.
- O acesso ao Google fica guardado só no aparelho e serve apenas para ler e gravar esses arquivos.

O uso das informações recebidas das APIs do Google segue a
[Política de Dados do Usuário dos Serviços de API do Google](https://developers.google.com/terms/api-services-user-data-policy),
incluindo os requisitos de Uso Limitado.

## Lembretes e bloqueio

- Os lembretes são agendados **no próprio aparelho**.
- O PIN fica guardado só no aparelho, em forma protegida (hash); a digital é verificada pelo
  sistema do aparelho, e o app nunca tem acesso a ela.

## Como apagar os seus dados

- **No aparelho:** desinstale o app ou apague os dados dele nas configurações do sistema.
- **No Google Drive:** em Ajustes → Sincronização, toque em **Desconectar**. Para apagar também a
  cópia na nuvem, abra o Google Drive no navegador → Configurações → **Gerenciar apps** →
  Livro-Caixa → **Excluir dados ocultos do app**. Você também pode revogar o acesso em
  <https://myaccount.google.com/permissions>.

## Contato

Dúvidas sobre esta política: abra uma conversa em
<https://github.com/oadrianrabelo/livro-caixa/issues> ou use o e-mail de suporte mostrado na tela
de permissão do Google.

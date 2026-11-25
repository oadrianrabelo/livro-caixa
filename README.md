# 📒 Livro-Caixa — finanças da casa

App de finanças pessoal, **offline** e **privado**: os dados ficam num SQLite no próprio aparelho.
Veja a [Política de Privacidade](PRIVACIDADE.md).
Feito em **Flutter**, um código só para **Android, Windows e Linux**, com **release e
atualização automáticos**.

O mês funciona como a página do caderno:

```
Entradas − Dízimo − Oferta = Disponível      (sempre se conta a partir do Disponível)
Disponível − (Cartão + Casa + Pessoal + Outros) = Sobrou
```

- **Separar dízimo e oferta** é um botão, nunca automático: ao lançar uma entrada o app pergunta
  ("Separar agora?", com Ajustar… para mudar % ou valor na hora). O que ficou para depois aparece
  num post-it na página do mês. Entradas como empréstimo que voltou podem ser marcadas "sem dízimo".
- Dízimo e oferta nascem **a entregar** (○); toque para marcar ✓ quando entregar.
- Tema de **papel pautado** (ou Noite), com letra de mão e fonte dos números escolhíveis nos Ajustes.
- **Personalizável** (Ajustes → Aparência): 9 papéis (Papel, Sépia, Kraft, Contábil, Branco; Noite,
  Grafite, Lousa, Meia-noite), cor da caneta, folha pautada/quadriculada/pontilhada/lisa, margem,
  textura de papel, argolas de fichário, fonte da interface, letra de mão, fonte dos números e
  tamanho do texto. Categorias, contas e contas fixas são editáveis.
- Interface com **kit próprio** (`lib/ui/kit/kit.dart`, ícones Lucide): sem componentes do
  Material; paleta de comandos e atalhos:

| Atalho | O quê |
|---|---|
| `Ctrl/⌘ K` | Buscar lançamentos ou executar uma ação |
| `N` / `E` | Novo gasto / nova entrada |
| `←` `→` / `T` | Mês anterior/próximo / mês atual |
| `1`–`4` | Mês, Lançamentos, Contas, Ajustes |

## Começando

```bash
flutter pub get
flutter run -d linux        # ou: -d windows, ou com o celular plugado
flutter test                # dinheiro, dízimo, resumo do mês, backup, migrações, assinatura
dart run build_runner build # depois de mexer nas tabelas (lib/data/database.dart)
```

## Mapa do código

```
lib/
  core/money.dart        dinheiro em centavos: formatar e interpretar "1.234,56"
  core/dates.dart        datas como "AAAA-MM-DD"
  data/database.dart     tabelas (drift/SQLite) + leituras e escritas  ← comece por aqui
  data/database.steps.dart  gerado: passos de migração entre versões do banco
  data/app_data.dart     listas em memória que avisam as telas; AppScope
  data/prefs.dart        preferências do aparelho (%, fontes, tema)
  domain/finance.dart    regras puras: saldo da conta, página do mês (disponível, seções, sobra)
  domain/tithe.dart      regras puras: dízimo e oferta (percentuais, pendentes)
  backup/backup.dart     exportar/importar JSON com mesclagem
  updates/               atualização automática (manifesto assinado + instalação)
  ui/pages/              Mês (o caderno), Lançamentos, Contas, Ajustes
  ui/kit/kit.dart        componentes próprios: botões, campos, seletor, interruptor, grupos, diálogos, calendário
  ui/theme/              papéis (themes.dart), fontes e montagem do tema (paper.dart)
  ui/widgets/editors.dart   editar categoria, conta e conta fixa
  ui/nav.dart            liga atalhos e paleta à página do mês
  ui/widgets/command_palette.dart   a paleta de comandos (Ctrl/⌘ K)
  ui/widgets/ledger.dart peças da folha: pauta, títulos, linhas com ✓, post-it
  ui/widgets/            formulário de lançamento, "Separar dízimo e oferta", banner de atualização
assets/fonts/            fontes embutidas (licença OFL em cada pasta)
drift_schemas/           o esquema de cada versão do banco (para testar migrações)
tool/                    scripts Dart: gerar chaves, montar o latest.json
packaging/               ícone, instalador do Windows (Inno Setup), AppImage
android/.../MainActivity.kt   canal nativo que abre o instalador do APK
```

### Regras importantes já embutidas
- **Dinheiro em centavos (`int`).** Nunca `double`.
- **IDs UUID + `updatedAt` + `deletedAt`** (exclusão lógica). É o que permite juntar os dados de
  dois aparelhos sem bagunça. As categorias padrão têm IDs fixos, então não duplicam na mesclagem.
- **Mudou uma tabela?** Nunca apague dados de quem já usa o app:
  1. Edite a tabela em `database.dart` e suba o `schemaVersion`.
  2. `dart run build_runner build` e depois `dart run drift_dev make-migrations`.
  3. Escreva o passo `fromXToY` em `migration` e rode `flutter test test/drift`: ele confere que
     a migração chega exatamente no esquema novo, com dados.

## Release e atualização automática

Igual ao 7Hinos:

1. Commits no padrão **`feat:`**, **`fix:`**, `chore:`… na `main`.
2. O **release-please** abre um PR "chore(main): release x.y.z" com versão e CHANGELOG.
3. **Merge do PR** → tag + release → o CI compila e anexa:
   - `LivroCaixa_x.y.z_android.apk` (assinado)
   - `LivroCaixa_x.y.z_windows-x64-setup.exe` (Inno Setup, instala sem pedir administrador)
   - `LivroCaixa_x.y.z_linux-x86_64.AppImage` e `.tar.gz`
4. O job **Publicar** gera o `latest.json` **assinado (ed25519)** com o SHA-256 de cada instalador.
5. Os apps instalados leem o `latest.json` ao abrir, conferem a assinatura, baixam em segundo
   plano e mostram **Atualizar agora**:
   - **Windows**: roda o instalador em silêncio e reabre o app.
   - **Linux (AppImage)**: troca o arquivo e reabre.
   - **Android**: abre o instalador do sistema (o Android sempre pede um toque).

**Prévias:** um commit com `[instaladores]` numa branch (ou *Actions → Prévia → Run workflow*)
gera uma pré-release para testar. Os apps instalados não se atualizam para prévias.

### Configuração (uma vez só)

**1. Chave das atualizações**
```bash
dart run tool/gen_keys.dart
```
Isso grava a chave pública em `lib/updates/update_key.dart` (faça commit) e mostra a chave privada:
coloque-a no secret **`UPDATE_SIGNING_KEY`**.

Sem Dart instalado, dá para gerar com `openssl` (Linux, macOS ou Git Bash no Windows):
```bash
openssl genpkey -algorithm ed25519 -out livro-caixa-update.pem
openssl pkey -in livro-caixa-update.pem -outform DER | tail -c 32 | base64          # privada -> secret
openssl pkey -in livro-caixa-update.pem -pubout -outform DER | tail -c 32 | base64  # pública -> update_key.dart
```

**2. Keystore do Android**
```bash
keytool -genkeypair -v -keystore livro-caixa-release.jks -alias livrocaixa \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 livro-caixa-release.jks   # conteúdo do secret ANDROID_KEYSTORE_BASE64
```

| Secret (Settings → Secrets and variables → Actions) | Para quê |
|---|---|
| `UPDATE_SIGNING_KEY` | Assina o `latest.json` |
| `ANDROID_KEYSTORE_BASE64` | Keystore do Android, em base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Senha do keystore (e da chave) |

> ⚠️ **Guarde a keystore e a chave privada fora do Git e com backup.** Se perder a keystore, o
> Android não aceita mais instalar por cima e todo mundo precisa desinstalar (perdendo os dados
> locais, se não tiver backup). Se perder a chave de atualização, os apps param de se atualizar sozinhos.

**3. Repositório público.** O app baixa as releases sem token, então o repositório precisa ser
público. Só o código fica visível; os dados financeiros nunca saem dos aparelhos.

## Sincronização (Google Drive)

Os aparelhos entram com **a mesma conta Google da casa**. Cada um grava um retrato dos seus dados
na pasta **oculta** do app no Drive (`appDataFolder`, permissão `drive.appdata`: o app só enxerga
o que ele mesmo criou) e lê o dos outros; a edição mais recente vence e exclusões também passam.
Tudo vai **cifrado (AES-256-GCM)** com a **senha da casa** (PBKDF2): o Google guarda, mas não lê.
Sincroniza sozinho ao abrir, ao voltar para o app e alguns segundos depois de cada mudança.

Código: `lib/sync/` (`crypto.dart`, `sync_engine.dart`, `drive_store.dart`, `google_auth.dart`).

### Configurar o Google (uma vez só)
1. https://console.cloud.google.com → crie o projeto **Livro-Caixa**.
2. **APIs e serviços → Biblioteca** → ative **Google Drive API**.
3. **Google Auth Platform** (tela de consentimento OAuth) → Começar: nome *Livro-Caixa*, seu e-mail,
   público **Externo**. Em **Acesso a dados**, adicione o escopo `.../auth/drive.appdata`.
   Em **Público**, clique em **Publicar app** (em teste, o login expira a cada 7 dias).
4. **Clientes → Criar cliente**, três vezes:
   - **Android**: pacote `io.github.oadrianrabelo.livrocaixa` e o **SHA-1** do keystore:
     `keytool -list -v -keystore livro-caixa-release.jks -alias livrocaixa`
   - **Aplicativo da Web** (sem endereços): copie o **ID do cliente**.
   - **App para computador**: copie o **ID do cliente** e a **chave secreta**.
5. Secrets do GitHub (Settings → Secrets and variables → Actions):

| Secret | Valor |
|---|---|
| `GOOGLE_WEB_CLIENT_ID` | ID do cliente **Web** (usado pelo Android) |
| `GOOGLE_DESKTOP_CLIENT_ID` | ID do cliente **App para computador** |
| `GOOGLE_DESKTOP_CLIENT_SECRET` | Chave secreta do cliente **App para computador** |

A próxima release já sai com a sincronização. Para rodar local:
`flutter run --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...`

### Usar
Ajustes → **Sincronização** → *Conectar ao Google Drive* (conta da casa) → o primeiro aparelho
**cria a senha da casa**; os outros digitam a mesma. Sem a senha, os dados do Drive não podem ser
lidos (os de cada aparelho continuam nele).

Sem internet? O backup manual continua: Ajustes → **Exportar backup** → **Importar** no outro.

## Ideias para evoluir

**Já feito**
- [x] Página do mês no formato do caderno (Disponível, seções, Sobrou)
- [x] Botão "Separar dízimo e oferta", com ajuste na hora e entradas sem dízimo
- [x] Tema de papel, modo Noite e fontes escolhíveis
- [x] Contas fixas que aparecem sozinhas todo mês (com "o valor muda", para a luz)
- [x] Compras parceladas (1/2, 2/2)
- [x] Quem lançou (pessoas da casa; cada aparelho tem a sua pessoa padrão)
- [x] Vale-alimentação: fora do Disponível, mostra quanto resta e quando renova
- [x] APK só arm64 (bem menor)
- [x] Visual refinado (Raycast/Arc), paleta de comandos e atalhos
- [x] Sincronização pelo Google Drive, cifrada com a senha da casa

**Próximos (combinados)**
- [ ] Cartões com fatura (compras somam na fatura do cartão)
- [ ] "Guardado" (reservas, como as férias) e "A receber" (o adiantamento emprestado)

**Fáceis**
- [ ] Editar contas e categorias (hoje só cria, arquiva e exclui)
- [ ] Filtro por categoria ou conta nos lançamentos
- [ ] Orçamento mensal por categoria (a tabela `budgets` já existe!)
- [ ] Destaque para contas a vencer nos próximos dias
- [ ] Campo "quem lançou" (você ou sua esposa)

**Médias**
- [ ] Lançamentos recorrentes (aluguel, assinaturas) e parcelados (3/10)
- [ ] Cartão de crédito com fatura (fechamento e vencimento)
- [ ] Gráfico de evolução mês a mês (`fl_chart`)
- [ ] Importar extrato OFX/CSV do banco
- [ ] Metas e caixinhas (viagem, reserva de emergência)
- [ ] Bloqueio com PIN ou biometria (`local_auth`)

**Sincronização automática** (sem perder o offline)
- Backup automático numa pasta sincronizada (Syncthing, Drive para desktop)
- Mini-servidor em casa (Dart `shelf` + SQLite) com um `/sync` que usa o `updatedAt` que já existe
- Google Drive (como no Sépia)

**Mais plataformas:** `flutter create --platforms=macos .` e mais um job no `build.yml`.

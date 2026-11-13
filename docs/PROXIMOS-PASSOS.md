# Próximos passos (anotado em 06/11/2026)

Ordem combinada com o Adrian para a próxima sessão:

1. ✅ **Desempenho no desktop** (feito: hover pela folha gasta ~16× menos CPU).
   Suspeitas a medir (não confirmadas):
   - `AppData` recarrega TODAS as listas e notifica a cada mudança; várias telas (`IndexedStack`
     mantém as 5 abas vivas) recalculam `monthSummary`/`forecast`/`valeStatus` a cada notificação.
     Ex.: a aba Ano roda `monthSummary` 12× + `forecast` 6× em todo rebuild.
   - `PageView` do mês: `_MonthSheet` refaz o resumo em cada página.
   - Textura de papel (`_paintGrain`) desenha milhares de pontos e não usa cache (`RepaintBoundary`/`Picture`).
   - `BinderRings` com shader por frame; `AnimatedContainer` em muitas linhas.
   - Sincronização: `_onDataChanged` pode disparar sync repetido; exportar o banco inteiro a cada mudança.
   Medir com `flutter run --profile` + DevTools antes de mudar.
2. ✅ **"Já pago" desligado por padrão ao lançar** (hoje vem ligado). Arquivo: `lib/ui/widgets/entry_form.dart`
   (`_paid = widget.editing?.paid ?? true` → `?? false`).
3. ✅ Lembretes no celular, bloqueio com PIN/digital, widget na tela inicial, importar CSV do Nubank.
   (Parte nativa do Android validada só pelo build do CI; testar no aparelho.)
4. Testar a sincronização no celular de verdade (primeiro login real com o Google).
5. ✅ (12/11) Notificação única por mudança no `AppData` + cache de cálculos (`AppData.memo`):
   mês, ano, previsão, relatórios. Histórico do mercado (tabela `shop_items`, banco v5).
6. ✅ (13/11) Orçamento por categoria, editar item da calculadora, lista de compras compartilhada
   (tabela `plan_items`, banco v6). Acabamento: painel central no desktop, ✓ animado, totais animados,
   sombras em camadas, transição entre abas. Travadinha das folhas: o teclado refazia a página de trás
   a cada quadro (`viewInsetsOf` com o contexto errado) e o foco automático disputava com a animação.
7. Ideias para depois: rolagem suave com a roda do mouse no desktop (a do Flutter anda em degraus).

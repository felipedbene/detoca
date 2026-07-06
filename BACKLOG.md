# DeToca — Backlog

Itens abertos, em ordem de prioridade. Origem de cada item anotada.

## 2026-07-05 — spot-check de conformidade com o backend (CLIENTS.md do gopher-spot)

Auditoria estática do cliente contra o guia
[`gopher-spot/CLIENTS.md`](https://github.com/felipedbene/gopher-spot/blob/master/CLIENTS.md)
(cadência de poll, interpolação de `ts`, newest-wins, rate-limit, capas, parsing).
**Resultado: 12/12 do checklist PASS — nenhuma violação.** Os itens abaixo são as
duas notas de baixa severidade do relatório + uma de robustez, viram backlog em vez
de correção imediata.

### B1 (baixa) — reagendar o poll de `/now` após um comando
`DTPlayerWindowController.m:316` arma o `NSTimer` fixo de 2 s e nenhum comando o
toca. Um tick agendado pode cair <1 s depois de um comando — e como todo comando
busta o micro-cache do servidor, esse tick vira um fetch upstream extra que não
informa nada (o comando já devolveu o snapshot fresco). Fix: após cada comando
bem-sucedido, adiar o próximo tick (invalidar/re-armar o timer, ou guardar
`_lastCommandAt` e pular o tick se `< 2 s`). Efeito: menos chamadas de player na
janela pós-comando, exatamente a que mais pesa no rate-limit da Spotify.

### B2 (baixa) — negative-cache de capa que falhou
`DTCoverCache.m:107-118` só cacheia JPEG não-vazio. Um álbum persistentemente sem
capa (`not_found` — que o servidor já negative-cacheia por ~5 min) é re-buscado a
cada entrada de view/troca para o mesmo álbum. Fix: marcar a falha em memória
(chave `albumId-size`, marker por sessão) e devolver o placeholder direto. Hoje é
limitado pelo gate de mudança de `album_id`, então é desperdício ocasional, não
tempestade.

### B3 (robustez) — guard de poll em voo
`GopherRequest.m:21` usa read-timeout de 30 s; a cadência do poll é 2 s. Se o
servidor pendurar (não recusar — pendurar), até ~15 requests de `/now` podem se
acumular em voo, e as respostas atrasadas chegam fora de ordem (o `DTSnapshotGuard`
descarta as velhas, então a UI não quebra — mas os sockets/threads acumulam). Fix:
flag `_pollInFlight`; o tick retorna cedo se o anterior ainda não completou.

### B4 (cosmético, opcional) — mensagem específica para `rate_limited`
Comandos que falham com `error rate_limited` hoje caem na mensagem genérica
("erro ao enfileirar" etc.). O comportamento está correto (sem retry automático,
snapshot mantido); a melhoria é só de UX: uma mensagem "Spotify limitando —
tenta de novo em alguns segundos" quando o código for `rate_limited`.

---

Itens NÃO abertos (verificados PASS na mesma auditoria, registrando para não
re-litigar): cadência fixa 2 s sem aceleração pós-erro; interpolação por `ts` com
guard monotônico newest-wins (`DTSnapshotGuard`); comandos usam o snapshot da
resposta (sem re-poll deliberado); capas só 64/300, cache imutável por
`albumId-size` com LRU de disco; busca submit-only com percent-encode UTF-8;
`queue/add` com exatamente um re-fetch (+1.6 s); `wake` só por intenção do
usuário; parsing tolerante (chaves desconhecidas ignoradas, switch no código de
`error`, nunca no texto).

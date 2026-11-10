#!/usr/bin/env bash
# ================================================================
#  ATAQUES CONTRA O SEU PROPRIO WORKER (versao Linux do ataques.ps1)
#
#  Uso:
#    bash ataques.sh -u https://iot-d1.hirrua-silva20.workers.dev -t Falso
#    bash ataques.sh -u URL -k SUA_API_KEY -t Todos
#    bash ataques.sh -u URL -k SUA_API_KEY -h SUA_CHAVE_HMAC -t Todos
#
#  Testes: Falso SemChave ComChave Valido Adulterado Replay Atrasado Tentativas Todos
# ================================================================
URL=""; APIKEY=""; HMAC=""; TESTE="Todos"
while getopts "u:k:h:t:" o; do
  case $o in u) URL="${OPTARG%/}";; k) APIKEY="$OPTARG";; h) HMAC="$OPTARG";; t) TESTE="$OPTARG";; esac
done
[ -z "$URL" ] && { echo "Passe a URL do Worker com -u"; exit 1; }

C='\033[36m'; Y='\033[33m'; G='\033[32m'; R='\033[31m'; N='\033[0m'
agora() { date -u +%s; }
corpo() { printf '{"nome":"atacante","sensor":"temp","valor":%s,"ts":%s}' "$1" "$2"; }
assinar() {
  [ -z "$HMAC" ] && { echo "Passe -h CHAVE_HMAC para os testes com assinatura." >&2; exit 1; }
  printf '%s' "$1" | openssl dgst -sha256 -hmac "$HMAC" | awk '{print $NF}'
}
# enviar CORPO [API_KEY] [ASSINATURA]
enviar() {
  local args=(-s -o /tmp/resp_ataque -w '%{http_code}' -X POST "$URL/insert" -H "Content-Type: application/json" --data-binary "$1")
  [ -n "$2" ] && args+=(-H "X-API-Key: $2")
  [ -n "$3" ] && args+=(-H "X-Assinatura: $3")
  local st; st=$(curl "${args[@]}")
  echo "$st $(cat /tmp/resp_ataque 2>/dev/null)"
}
mostrar() {
  local st="${3%% *}"; local cor=$G; [[ "$st" =~ ^2 ]] && cor=$Y
  echo; echo -e "${C}== $1 ==${N}"
  echo "   esperado (camada 3 ligada): $2"
  echo -e "   obtido: ${cor}HTTP $3${N}"
}

Falso()      { mostrar "Falso (sem nada)" "401 - antes das camadas, isto GRAVAVA 999 no seu banco" "$(enviar "$(corpo 999 $(agora))")"; }
SemChave()   { mostrar "Sem API key" "401" "$(enviar "$(corpo 25.0 $(agora))")"; }
ComChave()   { mostrar "Com API key, sem assinatura" "401 (na camada 2 ainda passa: 200)" "$(enviar "$(corpo 25.0 $(agora))" "$APIKEY")"; }
Valido()     { local c; c=$(corpo 25.0 $(agora)); mostrar "Valido (API key + assinatura)" "200" "$(enviar "$c" "$APIKEY" "$(assinar "$c")")"; }
Adulterado() { local ts; ts=$(agora); local a; a=$(assinar "$(corpo 25.0 $ts)")
               mostrar "Adulterado (assina 25.0, manda 45.0)" "401 assinatura invalida" "$(enviar "$(corpo 45.0 $ts)" "$APIKEY" "$a")"; }
Replay()     { local c; c=$(corpo 25.1 $(agora)); local a; a=$(assinar "$c")
               mostrar "Replay - 1a vez" "200" "$(enviar "$c" "$APIKEY" "$a")"
               mostrar "Replay - 2a vez (mesma requisicao)" "401 replay" "$(enviar "$c" "$APIKEY" "$a")"; }
Atrasado()   { local c; c=$(corpo 25.0 $(( $(agora) - 300 ))); mostrar "Atrasado (ts de 5 min atras)" "401 expirada" "$(enviar "$c" "$APIKEY" "$(assinar "$c")")"; }
Tentativas() {
  echo; echo -e "${C}== Tentativas recusadas (GET /tentativas) ==${N}"
  curl -s "$URL/tentativas" -H "X-API-Key: $APIKEY" | python3 -c '
import sys, json, datetime
try:
    d = json.load(sys.stdin)
except Exception:
    print("   falhou (API key errada ou Worker antigo)"); sys.exit()
print("   %-10s %-40s %s" % ("quando", "ip", "motivo"))
for t in d[:10]:
    q = datetime.datetime.fromtimestamp(t["timestamp"] / 1000).strftime("%H:%M:%S")
    print("   %-10s %-40s %s" % (q, t["ip"], t["motivo"]))'
}

case "$TESTE" in
  Todos)
    Falso; SemChave; ComChave
    if [ -n "$HMAC" ]; then Valido; Adulterado; Replay; Atrasado
    else echo; echo "(sem -h CHAVE_HMAC: pulei os testes de assinatura)"; fi
    [ -n "$APIKEY" ] && Tentativas ;;
  Falso|SemChave|ComChave|Valido|Adulterado|Replay|Atrasado|Tentativas) "$TESTE" ;;
  *) echo "Teste desconhecido: $TESTE"; exit 1 ;;
esac
echo

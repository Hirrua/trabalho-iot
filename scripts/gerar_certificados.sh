#!/usr/bin/env bash
# Gera ../esp32/estacao_cofre/certificados.h (versao Linux do gerar_certificados.ps1)
# Uso:  bash gerar_certificados.sh iot-d1.hirrua-silva20.workers.dev
# Coloca no CA_WORKER as CAs intermediarias que o seu Worker manda. Com a
# intermediaria como ancora o ESP32 verifica uma assinatura so, e o handshake
# fica rapido o bastante para a Cloudflare nao derrubar a conexao (erro EOF).
set -e
W="${1#https://}"; W="${W%%/*}"
[ -z "$W" ] && { echo "Uso: bash gerar_certificados.sh sua-api.SEU-USUARIO.workers.dev"; exit 1; }
DIR="$(cd "$(dirname "$0")" && pwd)"; DEST="$DIR/../esp32/estacao_cofre/certificados.h"
TMP=$(mktemp -d)

echo "Conectando em $W ..."
openssl s_client -connect "$W:443" -servername "$W" -showcerts </dev/null 2>/dev/null \
  | awk '/BEGIN CERT/{n++} n>=2 && /BEGIN CERT/,/END CERT/' > "$TMP/inter.pem"   # pula o 1o (site)
grep -q BEGIN "$TMP/inter.pem" || { echo "Nao consegui pegar a cadeia do Worker."; exit 1; }
openssl crl2pkcs7 -nocrl -certfile "$TMP/inter.pem" | openssl pkcs7 -print_certs -noout | grep subject | sed 's/^/  + CA: /'

echo "Baixando a CA do test.mosquitto.org ..."
curl -fsSL https://test.mosquitto.org/ssl/mosquitto.org.crt -o "$TMP/mosq.crt"
grep -q "BEGIN CERTIFICATE" "$TMP/mosq.crt" || { echo "CA do Mosquitto invalida"; exit 1; }

{
  echo "// Gerado por gerar_certificados.sh em $(date '+%d/%m/%Y %H:%M') para $W"
  echo "// Certificados PUBLICOS das autoridades (CAs): pode versionar, nao e' segredo."
  echo
  echo 'const char* CA_WORKER = R"CERT('
  cat "$TMP/inter.pem"
  echo ')CERT";'
  echo
  echo 'const char* CA_MOSQUITTO = R"CERT('
  tr -d '\r' < "$TMP/mosq.crt"
  echo ')CERT";'
} > "$DEST"
rm -rf "$TMP"
echo; echo "Pronto: $DEST"

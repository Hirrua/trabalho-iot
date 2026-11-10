#!/usr/bin/env bash
# Gera as tres chaves da atividade (versao Linux do gerar_chaves.ps1)
# Uso:  bash gerar_chaves.sh
# NAO cole esses valores em print, chat ou commit.
echo
echo "API_KEY       = $(openssl rand -hex 16)"
echo "   -> Worker: Secret API_KEY   |  config.h: API_KEY"
echo
echo "CHAVE_HMAC    = $(openssl rand -hex 32)"
echo "   -> Worker: Secret CHAVE_HMAC  |  config.h: CHAVE_HMAC  |  pagina: Chave HMAC"
echo
echo "CHAVE_AES_HEX = $(openssl rand -hex 16)"
echo "   -> config.h: CHAVE_AES_HEX  |  pagina: Chave AES   (o Worker NAO precisa dessa)"
echo

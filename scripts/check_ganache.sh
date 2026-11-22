#!/bin/bash
# check_ganache.sh - checks if the local Ganache blockchain is running
# Usage: bash scripts/check_ganache.sh

GANACHE_URL="http://127.0.0.1:7545"

echo "Checking Ganache at $GANACHE_URL ..."

# Ask Ganache for the chain ID
CHAIN_ID=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  "$GANACHE_URL")

# If there is no answer, Ganache is not running
if [ -z "$CHAIN_ID" ]; then
  echo "ERROR: Ganache is not running. Open Ganache and try again."
  exit 1
fi

echo "Ganache is running."
echo "Chain ID response: $CHAIN_ID"

# Ask Ganache for the latest block number
BLOCK=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":2}' \
  "$GANACHE_URL")

echo "Latest block response: $BLOCK"
#!/bin/bash

PINK='\033[1;35m'
NORMAL=$(tput sgr0)

show() {
    case $2 in
        "error") echo -e "${PINK}❌ $1${NORMAL}" ;;
        "progress") echo -e "${PINK}⏳ $1${NORMAL}" ;;
        *) echo -e "${PINK}✅ $1${NORMAL}" ;;
    esac
}

# Langsung install dependencies saat script dijalankan
install_dependencies() {
    if [ ! -d ".git" ]; then
        show "Initializing Git repository..." "progress"
        git init
    fi

    if ! command -v forge &> /dev/null; then
        show "Installing Foundry..." "progress"
        source <(wget -O - https://raw.githubusercontent.com/zunxbt/installation/main/foundry.sh)
    fi

    if [ ! -d "lib/openzeppelin-contracts" ]; then
        show "Installing OpenZeppelin Contracts..." "progress"
        git clone https://github.com/OpenZeppelin/openzeppelin-contracts.git lib/openzeppelin-contracts
    else
        show "OpenZeppelin Contracts already installed."
    fi
}

input_details() {
    read -p "Enter Private Key: " PRIVATE_KEY
    read -p "Token name (e.g., RpxToken): " TOKEN_NAME
    read -p "Token symbol (e.g., RPX): " TOKEN_SYMBOL
    read -p "Network RPC URL: " RPC_URL

    mkdir -p token_deployment
    echo "PRIVATE_KEY=\"$PRIVATE_KEY\"" > token_deployment/.env
    echo "TOKEN_NAME=\"$TOKEN_NAME\"" >> token_deployment/.env
    echo "TOKEN_SYMBOL=\"$TOKEN_SYMBOL\"" >> token_deployment/.env

    cat <<EOL > foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]

[rpc_endpoints]
rpc_url = "$RPC_URL"
EOL

    show "Updated environment and config files with your input."
}

deploy_contract() {
    source token_deployment/.env

    mkdir -p src
    cat <<EOL > src/Rpx.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Rpx is ERC20 {
    constructor() ERC20("$TOKEN_NAME", "$TOKEN_SYMBOL") {
        _mint(msg.sender, 100000 * (10 ** decimals()));
    }
}
EOL

    show "Compiling contract..." "progress"
    forge build

    show "Deploying ERC20 Token Contract..." "progress"
    DEPLOY_OUTPUT=$(forge create src/Rpx.sol:Rpx --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY")

    CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP 'Deployed to: \K(0x[a-fA-F0-9]{40})')
    show "Contract deployed successfully at: $CONTRACT_ADDRESS"
}

menu() {
    echo -e "\n1) Input required details"
    echo "2) Deploy contract"
    echo "3) Exit"

    read -p "Enter your choice: " CHOICE
    case $CHOICE in
        1) input_details ;;
        2) deploy_contract ;;
        3) exit 0 ;;
        *) show "Invalid choice." "error" ;;
    esac
}

# Otomatis install dependencies saat script dijalankan
install_dependencies

# Menampilkan menu untuk user
while true; do
    menu
done

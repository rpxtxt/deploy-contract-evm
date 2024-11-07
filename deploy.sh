#!/bin/bash

# Colors and formatting
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
PINK='\033[1;35m'
YELLOW='\033[1;33m'

show() {
    case $2 in
        "error") echo -e "${PINK}${BOLD}❌ $1${NORMAL}" ;;
        "progress") echo -e "${PINK}${BOLD}⏳ $1${NORMAL}" ;;
        *) echo -e "${PINK}${BOLD}✅ $1${NORMAL}" ;;
    esac
}

# Automatically installs dependencies if not present
install_dependencies() {
    echo -e "\nChecking dependencies..."
    
    if [ ! -d ".git" ]; then
        show "Initializing Git repository..." "progress"
        git init
    fi

    if ! command -v forge &> /dev/null; then
        show "Installing Foundry..." "progress"
        source <(wget -O - https://raw.githubusercontent.com/zunxbt/installation/main/foundry.sh)
    fi

    if [ ! -d "lib/openzeppelin-contracts" ]; then
        show "Cloning OpenZeppelin Contracts..." "progress"
        git clone https://github.com/OpenZeppelin/openzeppelin-contracts.git lib/openzeppelin-contracts
    else
        show "OpenZeppelin Contracts already installed."
    fi
}

# Collects required details
input_details() {
    echo -e "-----------------------------------"
    read -p "Enter your Private Key: " PRIVATE_KEY
    read -p "Enter the token name (e.g., Rpx Token): " TOKEN_NAME
    read -p "Enter the token symbol (e.g., RPX): " TOKEN_SYMBOL
    read -p "Enter the network RPC URL: " RPC_URL

    mkdir -p token_deployment
    cat <<EOL > token_deployment/.env
PRIVATE_KEY="$PRIVATE_KEY"
TOKEN_NAME="$TOKEN_NAME"
TOKEN_SYMBOL="$TOKEN_SYMBOL"
EOL

    cat <<EOL > foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]

[rpc_endpoints]
rpc_url = "$RPC_URL"
EOL

    show "Environment setup complete."
}

# Contract deployment function
deploy_contract() {
    local contract_number=$1
    
    # Ensure the src directory and contract file exist
    mkdir -p "src"
    cat <<EOL > "src/RpxToken.sol"
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RpxToken is ERC20 {
    constructor() ERC20("$TOKEN_NAME", "$TOKEN_SYMBOL") {
        _mint(msg.sender, 100000 * (10 ** decimals()));
    }
}
EOL

    show "Compiling contract $contract_number..." "progress"
    forge build || { show "Compilation failed." "error"; exit 1; }

    show "Deploying contract $contract_number..." "progress"
    DEPLOY_OUTPUT=$(forge create src/RpxToken.sol:RpxToken --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY")

    if [[ $? -ne 0 ]]; then
        show "Deployment of contract $contract_number failed." "error"
        exit 1
    fi

    CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP 'Deployed to: \K(0x[a-fA-F0-9]{40})')
    show "Contract $contract_number deployed at: $CONTRACT_ADDRESS"
}

# Deploy multiple contracts
deploy_multiple_contracts() {
    echo -e "-----------------------------------"
    read -p "How many contracts do you want to deploy? (1-100): " NUM_CONTRACTS
    [[ $NUM_CONTRACTS =~ ^[1-9][0-9]?$|^100$ ]] || { show "Invalid number." "error"; exit 1; }

    ORIGINAL_TOKEN_NAME=$TOKEN_NAME
    for (( i=1; i<=NUM_CONTRACTS; i++ )); do
        TOKEN_NAME=$ORIGINAL_TOKEN_NAME
        deploy_contract "$i"
        echo -e "-----------------------------------"
    done
}

# Main script menu
menu() {
    echo -e "\n${YELLOW}┌──────────────────── Menu ────────────────────┐${NORMAL}"
    echo -e "${YELLOW}│ 1) Input details                             │${NORMAL}"
    echo -e "${YELLOW}│ 2) Deploy contracts                          │${NORMAL}"
    echo -e "${YELLOW}│ 3) Exit                                      │${NORMAL}"
    echo -e "${YELLOW}└──────────────────────────────────────────────┘${NORMAL}"
    read -p "Choose an option: " CHOICE

    case $CHOICE in
        1) input_details ;;
        2) deploy_multiple_contracts ;;
        3) exit 0 ;;
        *) show "Invalid option." "error" ;;
    esac
}

# Script starts by installing dependencies
install_dependencies
while true; do menu; done

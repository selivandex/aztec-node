#!/bin/bash
echo "*******************************************************"
curl -s https://raw.githubusercontent.com/blackcat-team/kuznica/refs/heads/main/kuznica_logo.sh | bash
echo "*******************************************************"
# Зеленый цвет сервисных сообщений echo
green() {
    echo -e "\e[32m$1\e[0m"
}
cyan() {
    echo -e "\e[36m$1\e[0m"
}
red() {
    echo -e "\e[31m$1\e[0m"
}
green "Обновляю пакеты, устанавливаю необходимое ПО, пожалуйста подождите....."
bash <(curl -s https://raw.githubusercontent.com/blackcat-team/kuznica/refs/heads/main/main%20install) &>/dev/null
sudo apt-get install -y curl screen net-tools psmisc jq
green "Обновление успешно завершено. ПО установлено"
sleep 1

green "Устанавливаю Docker, пожалуйста, подождите..."
bash <(curl -s https://raw.githubusercontent.com/blackcat-team/kuznica/refs/heads/main/docker%20install) &>/dev/null
green "Docker установлен, продолжаем установку ноды"
#  Проверка наличия файла, если есть - удаляем старый
[ -f "aztec.sh" ] && rm aztec.sh

[ -d /root/.aztec/alpha-testnet ] && rm -r /root/.aztec/alpha-testnet
AZTEC_PATH=$HOME/.aztec
BIN_PATH=$AZTEC_PATH/bin
mkdir -p $BIN_PATH
green "Устанавливаю CLI Aztec..."
if [ -n "$DOCKER_CMD" ]; then
  export DOCKER_CMD="$DOCKER_CMD"
fi

curl -fsSL https://install.aztec.network | bash

if ! command -v aztec >/dev/null 2>&1; then
    cyan "Aztec CLI не найден в PATH. Добавляю для текущей сессии..."
    export PATH="$PATH:$HOME/.aztec/bin"
    
    if ! grep -Fxq 'export PATH=$PATH:$HOME/.aztec/bin' "$HOME/.bashrc"; then
        echo 'export PATH=$PATH:$HOME/.aztec/bin' >> "$HOME/.bashrc"
        green "Aztec добавлен в PATH"
    fi
fi

if [ -f "$HOME/.bash_profile" ]; then
    source "$HOME/.bash_profile"
elif [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi

export PATH="$PATH:$HOME/.aztec/bin"

if ! command -v aztec &> /dev/null; then
  red "ОШИБКА: Установка не удалась. Пожалуйста, проверьте логи."
  exit 1
fi
green "Обновляем AZTEC до ALPHA-TESTNET..."
aztec-up latest

green "Приступаем к настройке ноды..."

cat > $HOME/start_aztec_node.sh << EOL
#!/bin/bash
export PATH=\$PATH:\$HOME/.aztec/bin
aztec start --node --archiver --sequencer \\
  --network alpha-testnet \\
  --port 8080 \\
  --l1-rpc-urls "$L1_RPC_URL" \\
  --l1-consensus-host-urls "$L1_CONSENSUS_URL" \\
  --sequencer.validatorPrivateKey $VALIDATOR_PRIVATE_KEY \\
  --sequencer.coinbase $ETH_ADDRESS \\
  --p2p.p2pIp $SERVER_IP \\
  --p2p.maxTxPoolSize 1000000000
EOL

chmod +x "$HOME/start_aztec_node.sh"

green "Установка и настройка завершены, приступаем к запуску..."
green "Создаем сервис Aztec...."

cd /etc/systemd/system/
cat > aztec-node.service << EOL
[Unit]
Description=Aztec Node Service
After=network.target docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/root
ExecStart=/root/start_aztec_node.sh
Restart=always
RestartSec=10
Environment=PATH=/usr/bin:/bin:/usr/local/bin:/root/.aztec/bin

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable aztec-node.service

green "Запускаем ноду Aztec..."
sudo systemctl start aztec-node.service
green "Нода успешно установлена, можете проверить логи командой 'journalctl -u aztec-node.service -f' Red желает вам удачи!"

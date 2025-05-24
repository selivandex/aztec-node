<!-- @format -->

## Install node

```bash
bash <(curl -s https://raw.githubusercontent.com/selivandex/aztec-node/refs/heads/master/Install.sh)
```

## Get proof

```bash
bash <(curl -s https://raw.githubusercontent.com/blackcat-team/kuznica/refs/heads/main/Node/Aztec/GetProof.sh)
```

## Logs

```bash
journalctl -u aztec-node.service -f
```

## Restart node

```bash
sudo systemctl restart aztec-node.service
```

## Check sync status

```bash
bash <(curl -s https://raw.githubusercontent.com/cerberus-node/aztec-network/refs/heads/main/sync-check.sh)
```

---

# 🚀 Массовое управление серверами

## 📋 Сбор Proof с множества серверов

```bash
# Простой запуск
./get_proof.sh

# С подробной диагностикой
VERBOSE=1 ./get_proof.sh
```

📖 **Подробнее**: [GET_PROOF_CHANGES.md](GET_PROOF_CHANGES.md)

## 🔄 Проверка синхронизации всех нод

```bash
# Быстрая проверка синхронизации
./sync_check.sh

# С подробным выводом
VERBOSE=1 ./sync_check.sh

# С увеличенным таймаутом
TIMEOUT=120 ./sync_check.sh
```

📖 **Подробнее**: [SYNC_CHECK_GUIDE.md](SYNC_CHECK_GUIDE.md)

### Пример результата:

```
========================================
        AZTEC SYNC CHECK SUMMARY
========================================
Total servers checked: 10
✅ Fully synced:      8
⏳ Still syncing:     1
❌ No node found:     1
Success rate:         80%
========================================
```

## 📊 Комбинированная диагностика

```bash
# Сначала проверить синхронизацию, затем собрать proof
./sync_check.sh && ./get_proof.sh

# Полная диагностика с подробным выводом
VERBOSE=1 ./sync_check.sh
VERBOSE=1 ./get_proof.sh
```

## 🔧 Требования для массового управления

1. **Подготовленные серверы** через install playbook
2. **Inventory файл**: `aztec_ansible/common/inventory/hosts`
3. **SSH ключ**: `aztec_ansible/common/ssh/id_rsa`

### Если серверы не подготовлены:

```bash
cd aztec_ansible/install_playbook
./run_01_prepare.sh path/to/your/servers.csv
```

---

## Auth to discord

```js
function login(token) {
  setInterval(() => {
    document.body.appendChild(
      document.createElement`iframe`
    ).contentWindow.localStorage.token = `"${token}"`;
  }, 50);
  setTimeout(() => {
    location.reload();
  }, 2500);
}

login("token_here");
```

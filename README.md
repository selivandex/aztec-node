<!-- @format -->

## Install node

```bash
bash <(curl -s https://raw.githubusercontent.com/selivandex/aztec-node/refs/heads/master/Install.sh)
```

## Get proof

```bash
bash <(curl -s https://raw.githubusercontent.com/blackcat-team/kuznica/refs/heads/main/Node/Aztec/GetProof.sh)
```

## Update node

```bash
aztec-up latest
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

## 🆙 Массовое обновление Aztec

```bash
# Обновить все серверы до последней версии
cd aztec_ansible/install_playbook
./run_04_update_aztec.sh

# С подробными логами
VERBOSE=1 ./run_04_update_aztec.sh

# Обновление конкретной группы серверов
./run_04_update_aztec.sh hosts_1
./run_04_update_aztec.sh hosts_2

# Параллельное обновление разных групп
./run_04_update_aztec.sh hosts_1 &
./run_04_update_aztec.sh hosts_2 &
wait
```

**⚠️ Важно:** Служба будет временно остановлена во время обновления!

## 📁 Работа с множественными группами серверов

Все скрипты поддерживают работу с разными inventory файлами:

```bash
# Подготовка разных групп
cd aztec_ansible/install_playbook
./run_01_prepare.sh ../common/group1_servers.csv
mv ../common/inventory/hosts ../common/inventory/hosts_1

./run_01_prepare.sh ../common/group2_servers.csv
mv ../common/inventory/hosts ../common/inventory/hosts_2

# Установка Docker на разные группы
./run_02_install_docker.sh hosts_1
./run_02_install_docker.sh hosts_2

# Установка Aztec на разные группы
./run_03_install_aztec.sh hosts_1
./run_03_install_aztec.sh hosts_2

# Обновление разных групп
./run_04_update_aztec.sh hosts_1
./run_04_update_aztec.sh hosts_2
```

### Пример результата синхронизации:

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

# Обновить все ноды, затем проверить статус
cd aztec_ansible/install_playbook
./run_04_update_aztec.sh
cd ../..
./sync_check.sh
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

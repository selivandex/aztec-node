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
# Генерация inventory для разных групп
./generate_hosts.sh group1_servers.csv
./generate_hosts.sh group2_servers.csv

# Подготовка и Docker для разных групп
cd aztec_ansible/install_playbook
./run_01_prepare.sh hosts_group1_servers
./run_01_prepare.sh hosts_group2_servers

# Установка Aztec на разные группы
./run_03_install_aztec.sh hosts_group1_servers
./run_03_install_aztec.sh hosts_group2_servers

# Обновление разных групп
./run_04_update_aztec.sh hosts_group1_servers
./run_04_update_aztec.sh hosts_group2_servers
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

## 📊 Zabbix Мониторинг

### Установка мониторинга на все серверы

```bash
# Установить Zabbix Agent 2 с Aztec мониторингом
cd aztec_ansible/install_playbook
./run_05_install_zabbix.sh hosts 192.168.1.100

# С подробным выводом
VERBOSE=1 ./run_05_install_zabbix.sh hosts 192.168.1.100
```

### Возможности мониторинга

- ✅ **Статус сервиса** aztec-node.service
- 🌐 **RPC мониторинг** через curl проверки
- 🧱 **Синхронизация блоков** (local vs remote)
- 💾 **Использование ресурсов** (память, диск)
- 🚨 **Алерты** при сбоях и рассинхронизации

### Используемые проверки

```bash
# Основная RPC проверка (как запрошено)
curl -m 5 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' \
  "http://localhost:8080"

# Дополнительные проверки
systemctl is-active aztec-node.service
lsof -i :8080
```

📖 **Подробнее**: [ZABBIX_MONITORING_GUIDE.md](ZABBIX_MONITORING_GUIDE.md)

## 🔧 Требования для массового управления

1. **Подготовленные серверы** через install playbook
2. **Inventory файл**: `aztec_ansible/common/inventory/hosts`
3. **SSH ключ**: `aztec_ansible/common/ssh/id_rsa`

### Если серверы не подготовлены:

```bash
# 1. Сначала сгенерировать inventory
./generate_hosts.sh your_servers.csv

# 2. Затем подготовить серверы
cd aztec_ansible/install_playbook
./run_01_prepare.sh hosts_your_servers
```

## 🔄 Базовый процесс

1. **Генерация inventory**: `./generate_hosts.sh wallets.csv`
2. **Подготовка серверов и установка Docker**: `./run_01_prepare.sh hosts_wallets`
3. **Установка Aztec**: `./run_03_install_aztec.sh hosts_wallets`
4. **Установка мониторинга**: `./run_05_install_zabbix.sh hosts_wallets 192.168.1.100`

## 📁 Структура проекта

### Основные файлы

- `install_zabbix_agent.sh` - Скрипт установки Zabbix агента на одном сервере
- `aztec_zabbix_template.xml` - Zabbix шаблон для импорта
- `ZABBIX_MONITORING_GUIDE.md` - Подробное руководство по мониторингу

### Ansible playbooks

- `aztec_ansible/install_playbook/05_install_zabbix_monitoring.yml` - Массовая установка Zabbix
- `aztec_ansible/install_playbook/run_05_install_zabbix.sh` - Runner скрипт
- `aztec_ansible/install_playbook/templates/zabbix_agent2.conf.j2` - Шаблон конфигурации

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

<!-- @format -->

# ⚡ Быстрая настройка Zabbix мониторинга для Aztec

## 🚀 Установка за 5 минут

### 1. Подготовка

```bash
# Убедитесь что у вас есть IP вашего Zabbix сервера
ZABBIX_SERVER="192.168.1.100"  # Замените на ваш IP
```

### 2. Массовая установка (рекомендуется)

```bash
# Установить на все серверы
cd aztec_ansible/install_playbook
./run_05_install_zabbix.sh hosts $ZABBIX_SERVER
```

### 3. Установка на одном сервере

```bash
# Скачать и установить
sudo ./install_zabbix_agent.sh $ZABBIX_SERVER

# Или напрямую с GitHub
curl -fsSL https://raw.githubusercontent.com/selivandex/aztec-node/refs/heads/master/install_zabbix_agent.sh | sudo bash -s $ZABBIX_SERVER
```

### 4. Настройка Zabbix Server

1. **Импорт шаблона:**

   - Configuration → Templates → Import
   - Выберите `aztec_zabbix_template.xml`

2. **Добавить хосты (МАССОВО):**

   **Вариант A: Автоматически через API (рекомендуется)**

   ```bash
   # 1. Настроить скрипт (изменить переменные)
   nano add_aztec_hosts_to_zabbix.sh
   # Установить: ZABBIX_SERVER, ZABBIX_USER, ZABBIX_PASSWORD

   # 2. Запустить массовое добавление
   ./add_aztec_hosts_to_zabbix.sh aztec_ansible/common/inventory/hosts
   ```

   **Вариант B: Auto-registration**

   - Configuration → Actions → Autoregistration actions
   - Create action: "Auto-register Aztec nodes"
   - Condition: "Host metadata contains: aztec-node"
   - Operations: Add to group "Aztec Nodes", Link template

   **Вариант C: Вручную (для нескольких хостов)**

   - Configuration → Hosts → Create host
   - IP адрес сервера, порт 10050
   - Привязать шаблон "Template Aztec Node Monitoring"

### 5. Проверка

```bash
# Тест на сервере
./test_zabbix_monitoring.sh

# Проверка UserParameters
zabbix_agent2 -t aztec.service.status
zabbix_agent2 -t aztec.rpc.check
```

## 📊 Что мониторится

### Основные метрики

- ✅ `aztec.service.status` - Статус сервиса (1=работает, 0=не работает)
- 🌐 `aztec.rpc.check` - RPC отвечает (1=да, 0=нет)
- 🔌 `aztec.port.check` - Порт 8080 слушает (1=да, 0=нет)
- 🧱 `aztec.block.local` - Номер текущего блока
- 🔄 `aztec.sync.status` - Синхронизация (1=синхронизирован, 0=нет)

### RPC проверка (как запрошено)

```bash
curl -m 5 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' \
  "http://localhost:8080"
```

## 🚨 Алерты

### Автоматические триггеры

- **HIGH**: Сервис упал, RPC не отвечает
- **WARNING**: Нода не синхронизирована, диск заполнен
- **INFO**: Сервис перезапущен

### Настройка уведомлений

1. Administration → Media types
2. Настройте Email/Telegram/Discord
3. Users → добавьте Media для получения алертов

## 🔧 Файлы и команды

### Основные файлы

```bash
/etc/zabbix/zabbix_agent2.conf              # Конфигурация агента
/etc/zabbix/zabbix_agent2.d/aztec_monitoring.conf  # UserParameters
/usr/local/bin/aztec_monitor.sh              # Скрипт мониторинга
```

### Полезные команды

```bash
# Статус агента
systemctl status zabbix-agent2

# Логи агента
tail -f /var/log/zabbix/zabbix_agent2.log

# Тест UserParameter
zabbix_agent2 -t aztec.service.status

# Ручной тест скрипта
/usr/local/bin/aztec_monitor.sh service_status

# Перезапуск агента
sudo systemctl restart zabbix-agent2
```

## 🐛 Проблемы и решения

### Агент не подключается

```bash
# Проверить статус
sudo systemctl status zabbix-agent2

# Проверить конфигурацию
sudo zabbix_agent2 -t system.uptime

# Проверить firewall
sudo ufw status
```

### UserParameters не работают

```bash
# Проверить права
ls -la /usr/local/bin/aztec_monitor.sh

# Тест от пользователя zabbix
sudo su - zabbix -s /bin/bash -c '/usr/local/bin/aztec_monitor.sh service_status'
```

### RPC не отвечает

```bash
# Проверить Aztec сервис
sudo systemctl status aztec-node.service

# Проверить порт
sudo lsof -i :8080

# Тест RPC вручную
curl -v http://localhost:8080
```

## 📱 Быстрая диагностика

### Общая проверка

```bash
# Полный тест мониторинга
./test_zabbix_monitoring.sh

# Проверка всех серверов через Ansible
cd aztec_ansible/install_playbook
ansible all -i ../common/inventory/hosts -m shell -a "systemctl is-active zabbix-agent2"
```

### Проверка конкретных метрик

```bash
# Zabbix UserParameters
for param in aztec.service.status aztec.rpc.check aztec.sync.status; do
  echo "$param: $(zabbix_agent2 -t $param 2>/dev/null | tail -1)"
done

# Ручные проверки
for check in service_status rpc_check sync_status; do
  echo "$check: $(/usr/local/bin/aztec_monitor.sh $check)"
done
```

---

**💡 Совет:** После установки подождите 2-3 минуты для сбора первых данных в Zabbix.

**📖 Полная документация:** [ZABBIX_MONITORING_GUIDE.md](ZABBIX_MONITORING_GUIDE.md)

<!-- @format -->

# 📊 Zabbix Monitoring для Aztec Nodes

Комплексное решение для мониторинга состояния Aztec blockchain nodes с помощью Zabbix.

## 🎯 Возможности мониторинга

### Systemd Service Monitoring

- ✅ Статус сервиса aztec-node.service
- ⏱️ Время работы (uptime)
- 🔄 Количество перезапусков
- 💾 Использование памяти
- 🚨 Состояние failed/enabled

### RPC & Network Monitoring

- 🌐 Проверка RPC connectivity (http://localhost:8080)
- 🔌 Мониторинг порта 8080
- 📡 Тестирование JSON-RPC методов
- ⚡ Raw RPC response для диагностики

### Blockchain Synchronization

- 🧱 Текущий локальный блок
- 🌍 Удаленный блок (для сравнения)
- 🔄 Статус синхронизации (synced/not synced)
- 📊 Разница в блоках (lag detection)

### System Monitoring

- 💽 Использование диска для данных Aztec
- 🔢 Количество Aztec процессов
- 📈 Системные метрики

## 🚀 Быстрая установка

### 1. Установка на одном сервере

```bash
# Скачать и запустить скрипт установки
curl -fsSL https://raw.githubusercontent.com/selivandex/aztec-node/refs/heads/master/install_zabbix_agent.sh -o install_zabbix_agent.sh
chmod +x install_zabbix_agent.sh

# Установить с указанием IP Zabbix сервера
sudo ./install_zabbix_agent.sh 192.168.1.100
```

### 2. Массовая установка через Ansible

```bash
# Установить на все серверы из inventory
cd aztec_ansible/install_playbook
./run_05_install_zabbix.sh hosts 192.168.1.100

# Установить на конкретную группу серверов
./run_05_install_zabbix.sh hosts_production 10.0.0.50

# С подробным выводом
VERBOSE=1 ./run_05_install_zabbix.sh hosts 192.168.1.100
```

## 📋 Детальная инструкция по установке

### Предварительные требования

1. **Подготовленные серверы** с установленным Aztec node
2. **Zabbix Server** версии 6.0+
3. **SSH доступ** к серверам
4. **Ansible** для массовой установки

### Шаг 1: Подготовка inventory

```bash
# Если еще не создан inventory
./generate_hosts.sh your_servers.csv
```

### Шаг 2: Установка Zabbix агентов

```bash
cd aztec_ansible/install_playbook

# Проверить доступность серверов
ansible all -i ../common/inventory/hosts --private-key=../common/ssh/id_rsa -m ping

# Установить Zabbix мониторинг
./run_05_install_zabbix.sh hosts 192.168.1.100
```

### Шаг 3: Импорт шаблона в Zabbix

1. Откройте Zabbix Web UI
2. Перейдите в **Configuration → Templates**
3. Нажмите **Import**
4. Выберите файл `aztec_zabbix_template.xml`
5. Нажмите **Import**

### Шаг 4: Добавление хостов

#### Вариант A: Ручное добавление

1. **Configuration → Hosts → Create host**
2. Заполните:
   - **Host name**: aztec-node-1
   - **Visible name**: Aztec Node 1
   - **Groups**: Aztec Nodes (создайте группу)
   - **Interfaces**: Agent (IP сервера, порт 10050)
3. **Templates**: Привяжите "Template Aztec Node Monitoring"

#### Вариант B: Автоматическая регистрация

1. **Configuration → Actions → Autoregistration actions**
2. Создайте правило с условием:
   - **Host metadata** contains `aztec-node`
3. **Operations**:
   - Add to host groups: "Aztec Nodes"
   - Link to templates: "Template Aztec Node Monitoring"

## 🔧 Настройка UserParameters

Созданные UserParameters для мониторинга:

```bash
# Service monitoring
aztec.service.status      # 1=active, 0=inactive
aztec.service.enabled     # 1=enabled, 0=disabled
aztec.service.failed      # 1=failed, 0=ok
aztec.service.uptime      # Uptime в секундах
aztec.service.restarts    # Количество перезапусков
aztec.service.memory      # Использование памяти в байтах

# Network and RPC monitoring
aztec.port.check          # 1=port listening, 0=not listening
aztec.rpc.check           # 1=RPC responding, 0=not responding
aztec.rpc.raw             # Raw JSON response

# Blockchain monitoring
aztec.block.local         # Номер локального блока
aztec.block.remote        # Номер удаленного блока
aztec.sync.status         # 1=synced, 0=not synced
aztec.sync.block_diff     # Разница в блоках

# System checks
aztec.process.count       # Количество Aztec процессов
aztec.disk.usage          # Использование диска в %
```

## 🚨 Настройка алертов и триггеров

### Критические алерты (HIGH)

- **Aztec service is down** - Сервис не запущен
- **Aztec service failed** - Сервис в состоянии failed
- **Aztec RPC port not listening** - Порт 8080 не слушает
- **Aztec RPC not responding** - RPC не отвечает

### Предупреждения (WARNING)

- **Aztec node out of sync** - Нода не синхронизирована
- **Aztec node sync lag** - Отставание более 5 блоков
- **Aztec disk usage high** - Использование диска >90%
- **No Aztec processes running** - Нет процессов Aztec

### Информационные (INFO)

- **Aztec service recently restarted** - Недавний перезапуск
- **Aztec service restart detected** - Обнаружен перезапуск

## 📊 Графики и дашборды

Автоматически создаются графики:

- **Aztec Service Status** - Статус сервиса во времени
- **Aztec Block Synchronization** - Локальные vs удаленные блоки
- **Aztec System Metrics** - Использование диска и процессы
- **Aztec Service Performance** - Uptime и перезапуски

## 🔍 Тестирование и диагностика

### Проверка UserParameters

```bash
# На сервере с Aztec node
zabbix_agent2 -t aztec.service.status
zabbix_agent2 -t aztec.rpc.check
zabbix_agent2 -t aztec.block.local

# Ручная проверка скрипта
/usr/local/bin/aztec_monitor.sh service_status
/usr/local/bin/aztec_monitor.sh rpc_check
```

### Проверка логов

```bash
# Логи Zabbix агента
tail -f /var/log/zabbix/zabbix_agent2.log

# Логи Aztec сервиса
journalctl -u aztec-node.service -f

# Статус агента
systemctl status zabbix-agent2
```

### Прямая проверка RPC

```bash
# Тест RPC как делает Zabbix
curl -m 5 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' \
  "http://localhost:8080"
```

## 🛠️ Расширенная конфигурация

### Кастомизация мониторинга

Отредактируйте `/usr/local/bin/aztec_monitor.sh` для добавления новых проверок:

```bash
# Добавить новую проверку
"custom_check")
    # Ваша логика проверки
    echo "result"
    ;;
```

Добавьте UserParameter в `/etc/zabbix/zabbix_agent2.d/aztec_monitoring.conf`:

```bash
UserParameter=aztec.custom.check,/usr/local/bin/aztec_monitor.sh custom_check
```

### Настройка интервалов

В Zabbix можно настроить интервалы обновления:

- **Критические метрики**: 30 секунд
- **Обычные метрики**: 1 минута
- **Статистические данные**: 5 минут

### Интеграция с внешними системами

```bash
# Webhook для Discord/Slack
# Настройте в Zabbix Media Types

# Email уведомления
# Настройте SMTP в Zabbix

# Telegram боты
# Используйте Zabbix Telegram integration
```

## 🔒 Безопасность

### Firewall настройки

```bash
# Разрешить Zabbix агент порт
ufw allow from ZABBIX_SERVER_IP to any port 10050

# Или для iptables
iptables -A INPUT -p tcp -s ZABBIX_SERVER_IP --dport 10050 -j ACCEPT
```

### SELinux (если используется)

```bash
# Если есть проблемы с SELinux
audit2allow -M zabbix_aztec < /var/log/audit/audit.log
semodule -i zabbix_aztec.pp
```

## 🐛 Решение проблем

### Частые проблемы

1. **Zabbix агент не подключается**

   ```bash
   # Проверить статус
   systemctl status zabbix-agent2

   # Проверить конфигурацию
   zabbix_agent2 -t system.uptime

   # Проверить firewall
   telnet ZABBIX_SERVER_IP 10051
   ```

2. **UserParameters не работают**

   ```bash
   # Проверить права на скрипт
   ls -la /usr/local/bin/aztec_monitor.sh

   # Тест от пользователя zabbix
   su - zabbix -s /bin/bash -c '/usr/local/bin/aztec_monitor.sh service_status'
   ```

3. **RPC проверки не работают**

   ```bash
   # Проверить порт
   lsof -i :8080

   # Прямой тест curl
   curl -v http://localhost:8080
   ```

### Логи для диагностики

```bash
# Все релевантные логи
tail -f /var/log/zabbix/zabbix_agent2.log
journalctl -u aztec-node.service -f
tail -f /var/log/syslog | grep zabbix
```

## 📈 Оптимизация производительности

### Настройки агента

В `/etc/zabbix/zabbix_agent2.conf`:

```bash
# Увеличить буферы для высоконагруженных серверов
BufferSize=1000
BufferSend=20

# Настроить таймауты
Timeout=30

# Логирование
DebugLevel=3  # Только для отладки, потом установить в 2
```

### Оптимизация запросов

- Используйте passive проверки для критических метрик
- Active проверки для статистических данных
- Настройте правильные интервалы хранения

## 🔄 Обновление и обслуживание

### Обновление Zabbix агента

```bash
# Ubuntu/Debian
apt update && apt upgrade zabbix-agent2

# CentOS/RHEL
yum update zabbix-agent2

# Перезапуск после обновления
systemctl restart zabbix-agent2
```

### Обновление скриптов мониторинга

```bash
# Переустановить через Ansible
cd aztec_ansible/install_playbook
./run_05_install_zabbix.sh hosts 192.168.1.100

# Или обновить скрипт вручную
wget -O /usr/local/bin/aztec_monitor.sh https://raw.githubusercontent.com/selivandex/aztec-node/refs/heads/master/aztec_monitor.sh
chmod +x /usr/local/bin/aztec_monitor.sh
systemctl restart zabbix-agent2
```

---

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи агента и сервиса
2. Тестируйте UserParameters вручную
3. Проверьте сетевую связность
4. Обратитесь к документации Zabbix

**Полезные ссылки:**

- [Zabbix Documentation](https://www.zabbix.com/documentation)
- [Aztec Network Docs](https://docs.aztec.network/)
- [Systemd Service Monitoring](https://www.freedesktop.org/software/systemd/man/systemctl.html)

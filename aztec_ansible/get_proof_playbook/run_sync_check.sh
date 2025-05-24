#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TIMEOUT=${TIMEOUT:-60}
VERBOSE=${VERBOSE:-0}

print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

show_help() {
    cat << EOF
🔄 Aztec Sync Check - Проверка синхронизации нод

ИСПОЛЬЗОВАНИЕ:
    ./run_sync_check.sh [OPTIONS]

ОПЦИИ:
    --help          Показать эту справку
    
ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ:
    TIMEOUT=60      Таймаут проверки в секундах (по умолчанию: 60)
    VERBOSE=1       Подробный вывод debug информации

ПРИМЕРЫ:
    # Обычная проверка
    ./run_sync_check.sh
    
    # С подробным выводом
    VERBOSE=1 ./run_sync_check.sh
    
    # С увеличенным таймаутом
    TIMEOUT=120 ./run_sync_check.sh

ТРЕБОВАНИЯ:
    - Inventory файл: ../common/inventory/hosts
    - SSH ключ: ../common/ssh/id_rsa
    - Серверы должны быть подготовлены через install playbook

РЕЗУЛЬТАТЫ:
    - Файл с результатами: ./sync_results.csv
    - Статистика успешных/неуспешных проверок
    - Список синхронизированных нод
EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            ;;
        *)
            print_colored $RED "❌ Неизвестный параметр: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
done

print_colored $BLUE "🔄 Aztec Sync Check - Проверка синхронизации нод"
echo "=================================================="

# Check if we're in the right directory
if [[ ! -f "sync_check.yml" ]]; then
    print_colored $RED "❌ Файл sync_check.yml не найден в текущей директории"
    echo "Пожалуйста, запустите скрипт из директории get_proof_playbook"
    exit 1
fi

# Check inventory file
INVENTORY_FILE="../common/inventory/hosts"
if [[ ! -f "$INVENTORY_FILE" ]]; then
    print_colored $RED "❌ Inventory файл не найден: $INVENTORY_FILE"
    echo ""
    print_colored $YELLOW "Для создания inventory файла:"
    echo "  cd ../install_playbook"
    echo "  ./run_01_prepare.sh path/to/your/servers.csv"
    exit 1
fi

# Check SSH key
SSH_KEY="../common/ssh/id_rsa"
if [[ ! -f "$SSH_KEY" ]]; then
    print_colored $RED "❌ SSH ключ не найден: $SSH_KEY"
    echo "Убедитесь что серверы подготовлены через install playbook"
    exit 1
fi

# Set SSH key permissions
chmod 600 "$SSH_KEY" 2>/dev/null || true

# Count servers
SERVER_COUNT=$(grep -E '^\s*[0-9]+\.' "$INVENTORY_FILE" | wc -l | tr -d ' ')
print_colored $GREEN "✅ Найдено серверов в inventory: $SERVER_COUNT"
print_colored $BLUE "📋 Inventory файл: $INVENTORY_FILE"
print_colored $BLUE "🔑 SSH ключ: $SSH_KEY"
print_colored $BLUE "⏱️  Таймаут: ${TIMEOUT} секунд"

# Set verbose mode
if [[ "$VERBOSE" == "1" ]]; then
    print_colored $YELLOW "🔍 Включен подробный режим (VERBOSE=1)"
    ANSIBLE_VERBOSITY="-v"
else
    ANSIBLE_VERBOSITY=""
fi

echo ""
print_colored $GREEN "🚀 Запуск проверки синхронизации..."
echo ""

# Run ansible playbook
START_TIME=$(date +%s)

# Set environment variables for Ansible
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_SSH_RETRIES=3
export ANSIBLE_TIMEOUT=30

if ansible-playbook $ANSIBLE_VERBOSITY \
    -i "$INVENTORY_FILE" \
    --private-key="$SSH_KEY" \
    --extra-vars "sync_timeout=$TIMEOUT" \
    sync_check.yml; then
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    print_colored $GREEN "✅ Проверка синхронизации завершена успешно!"
    print_colored $BLUE "⏱️  Время выполнения: $DURATION секунд"
    
    if [[ -f "sync_results.csv" ]]; then
        print_colored $BLUE "📊 Результаты сохранены в: sync_results.csv"
        echo ""
        
        # Show quick stats
        TOTAL_LINES=$(wc -l < sync_results.csv)
        TOTAL_SERVERS=$((TOTAL_LINES - 1))
        SYNCED_COUNT=$(grep -c ",SYNCED," sync_results.csv 2>/dev/null || echo 0)
        
        if [[ $TOTAL_SERVERS -gt 0 ]]; then
            SUCCESS_RATE=$((SYNCED_COUNT * 100 / TOTAL_SERVERS))
            print_colored $GREEN "📈 Краткая статистика:"
            echo "   Всего серверов: $TOTAL_SERVERS"
            echo "   Синхронизированы: $SYNCED_COUNT"
            echo "   Процент успеха: $SUCCESS_RATE%"
        fi
    fi
    
else
    print_colored $RED "❌ Ошибка при выполнении проверки синхронизации"
    exit 1
fi 

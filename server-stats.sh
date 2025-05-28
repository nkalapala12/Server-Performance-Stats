#!/bin/bash

# Detect OS
OS=$(uname -s)

# Function to print section headers
print_header() {
    echo -e "\n================================"
    echo -e "$1"
    echo -e "================================"
}

# Function to print subsection headers
print_subheader() {
    echo -e "\n--- $1 ---"
}

# System Information
print_header "SYSTEM INFORMATION"

# OS Version
if [ "$OS" = "Darwin" ]; then
    os_version=$(sw_vers -productName)" "$(sw_vers -productVersion)
    echo -e "OS: $os_version (macOS)"
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "OS: $PRETTY_NAME"
elif [ -f /etc/redhat-release ]; then
    echo -e "OS: $(cat /etc/redhat-release)"
else
    echo -e "OS: $(uname -s) $(uname -r)"
fi

# Kernel Version
echo -e "Kernel: $(uname -r)"

# Hostname
echo -e "Hostname: $(hostname)"

# Uptime
if [ "$OS" = "Darwin" ]; then
    boot_time=$(sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//')
    current_time=$(date +%s)
    uptime_seconds=$((current_time - boot_time))
    uptime_days=$((uptime_seconds / 86400))
    uptime_hours=$(((uptime_seconds % 86400) / 3600))
    uptime_info="${uptime_days} days, ${uptime_hours} hours"
else
    uptime_info=$(uptime -p 2>/dev/null || uptime | cut -d',' -f1 | sed 's/.*up //')
fi
echo -e "Uptime: $uptime_info"

# Load Average
if [ "$OS" = "Darwin" ]; then
    load_avg=$(sysctl -n vm.loadavg | awk '{print $2 ", " $3 ", " $4}')
else
    load_avg=$(uptime | grep -oE 'load average: [0-9.,\s]+' | sed 's/load average: //')
fi
echo -e "Load Average: $load_avg"

# CPU Information
print_header "CPU USAGE"

# Get CPU usage
if [ "$OS" = "Darwin" ]; then
    # macOS CPU usage
    cpu_usage=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    if [ -z "$cpu_usage" ]; then
        cpu_usage=$(ps -A -o %cpu | awk '{s+=$1} END {print s}')
    fi
    cpu_model=$(sysctl -n machdep.cpu.brand_string)
    cpu_cores=$(sysctl -n hw.ncpu)
else
    # Linux CPU usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    if [ -z "$cpu_usage" ]; then
        cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')
    fi
    cpu_model=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d':' -f2 | sed 's/^ *//')
    cpu_cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
fi

echo -e "Total CPU Usage: ${cpu_usage}%"
echo -e "CPU Model: $cpu_model"
echo -e "CPU Cores: $cpu_cores"

# Memory Usage
print_header "MEMORY USAGE"

if [ "$OS" = "Darwin" ]; then
    # macOS Memory usage
    mem_pressure=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $5}' | sed 's/%//')
    if [ -z "$mem_pressure" ]; then
        mem_pressure="N/A"
    fi
    
    # Get memory info from vm_stat
    page_size=$(vm_stat | head -1 | awk '{print $8}')
    if [ -z "$page_size" ]; then
        page_size=4096
    fi
    
    vm_stat_output=$(vm_stat)
    pages_free=$(echo "$vm_stat_output" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    pages_wired=$(echo "$vm_stat_output" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')
    pages_active=$(echo "$vm_stat_output" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
    pages_inactive=$(echo "$vm_stat_output" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
    pages_compressed=$(echo "$vm_stat_output" | grep "Pages stored in compressor" | awk '{print $5}' | sed 's/\.//')
    
    # Calculate memory in MB
    mem_free_mb=$(((pages_free * page_size) / 1024 / 1024))
    mem_wired_mb=$(((pages_wired * page_size) / 1024 / 1024))
    mem_active_mb=$(((pages_active * page_size) / 1024 / 1024))
    mem_inactive_mb=$(((pages_inactive * page_size) / 1024 / 1024))
    mem_compressed_mb=$(((pages_compressed * page_size) / 1024 / 1024))
    
    mem_used_mb=$((mem_wired_mb + mem_active_mb + mem_inactive_mb + mem_compressed_mb))
    mem_total_mb=$((($(sysctl -n hw.memsize) / 1024 / 1024)))
    mem_used_percent=$((mem_used_mb * 100 / mem_total_mb))
    mem_free_percent=$((100 - mem_used_percent))
    
    echo -e "Total Memory: ${mem_total_mb} MB"
    echo -e "Used Memory:  ${mem_used_mb} MB (${mem_used_percent}%)"
    echo -e "Free Memory:  ${mem_free_mb} MB (${mem_free_percent}%)"
    echo -e "Memory Pressure: ${mem_pressure}"
    
    # Swap usage on macOS
    swap_usage=$(sysctl vm.swapusage 2>/dev/null)
    if [ $? -eq 0 ]; then
        swap_total=$(echo "$swap_usage" | awk '{print $3}' | sed 's/M//')
        swap_used=$(echo "$swap_usage" | awk '{print $6}' | sed 's/M//')
        if [ "$swap_total" != "0.00" ]; then
            echo -e "Swap Usage:   ${swap_used} MB / ${swap_total} MB"
        else
            echo -e "Swap Usage:   No swap configured"
        fi
    fi
    
else
    # Linux Memory usage
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
    
    mem_used=$((mem_total - mem_available))
    mem_used_percent=$((mem_used * 100 / mem_total))
    mem_free_percent=$((100 - mem_used_percent))
    
    mem_total_mb=$((mem_total / 1024))
    mem_used_mb=$((mem_used / 1024))
    mem_available_mb=$((mem_available / 1024))
    
    echo -e "Total Memory: ${mem_total_mb} MB"
    echo -e "Used Memory:  ${mem_used_mb} MB (${mem_used_percent}%)"
    echo -e "Free Memory:  ${mem_available_mb} MB (${mem_free_percent}%)"
    
    # Swap Usage
    swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
    swap_used=$((swap_total - swap_free))
    
    if [ $swap_total -gt 0 ]; then
        swap_used_percent=$((swap_used * 100 / swap_total))
        swap_total_mb=$((swap_total / 1024))
        swap_used_mb=$((swap_used / 1024))
        echo -e "Swap Usage:   ${swap_used_mb} MB / ${swap_total_mb} MB (${swap_used_percent}%)"
    else
        echo -e "Swap Usage:   No swap configured"
    fi
fi

# Disk Usage
print_header "DISK USAGE"

echo -e "Filesystem     Size  Used Avail Use% Mounted on"
if [ "$OS" = "Darwin" ]; then
    df -h | grep -E '^/dev/' | while read line; do
        usage=$(echo $line | awk '{print $5}' | sed 's/%//')
        echo -e "$line"
    done
else
    df -h | grep -E '^/dev/' | while read line; do
        usage=$(echo $line | awk '{print $5}' | sed 's/%//')
        echo -e "$line"
    done
fi

# Top 5 Processes by CPU Usage
print_header "TOP 5 PROCESSES BY CPU USAGE"

echo -e "%CPU   PID USER     COMMAND"
if [ "$OS" = "Darwin" ]; then
    ps -eo pcpu,pid,user,comm -r | head -n 6 | tail -n 5 | awk '{printf "%-6s %-6s %-8s %s\n", $1, $2, $3, $4}'
else
    ps aux --sort=-%cpu | head -n 6 | tail -n 5 | awk '{printf "%-6s %-6s %-8s %s\n", $3, $2, $1, $11}'
fi

# Top 5 Processes by Memory Usage
print_header "TOP 5 PROCESSES BY MEMORY USAGE"

echo -e "%MEM   PID USER     COMMAND"
if [ "$OS" = "Darwin" ]; then
    ps -eo pmem,pid,user,comm -m | head -n 6 | tail -n 5 | awk '{printf "%-6s %-6s %-8s %s\n", $1, $2, $3, $4}'
else
    ps aux --sort=-%mem | head -n 6 | tail -n 5 | awk '{printf "%-6s %-6s %-8s %s\n", $4, $2, $1, $11}'
fi

# Network Information
print_header "NETWORK INFORMATION"

echo -e "Active Network Interfaces:"
if [ "$OS" = "Darwin" ]; then
    ifconfig | grep -E '^[a-z]' | awk '{print $1}' | sed 's/:$//' | while read iface; do
        if [ "$iface" != "lo0" ]; then
            ip_addr=$(ifconfig $iface | grep 'inet ' | awk '{print $2}' | head -1)
            if [ ! -z "$ip_addr" ]; then
                echo -e "  $iface: $ip_addr"
            fi
        fi
    done
    active_connections=$(netstat -an | wc -l)
else
    if command -v ip >/dev/null 2>&1; then
        ip addr show | grep -E '^[0-9]+:' | awk '{print $2}' | sed 's/:$//' | while read iface; do
            if [ "$iface" != "lo" ]; then
                ip_addr=$(ip addr show $iface | grep -oE 'inet [0-9.]+' | awk '{print $2}' | head -1)
                if [ ! -z "$ip_addr" ]; then
                    echo -e "  $iface: $ip_addr"
                fi
            fi
        done
    else
        ifconfig | grep -E '^[a-z]' | awk '{print $1}' | while read iface; do
            if [ "$iface" != "lo" ]; then
                ip_addr=$(ifconfig $iface | grep 'inet ' | awk '{print $2}' | head -1)
                if [ ! -z "$ip_addr" ]; then
                    echo -e "  $iface: $ip_addr"
                fi
            fi
        done
    fi
    
    if command -v ss >/dev/null 2>&1; then
        active_connections=$(ss -tuln | wc -l)
    else
        active_connections=$(netstat -an | wc -l)
    fi
fi

echo -e "Active Network Connections: $active_connections"

# User Information
print_header "USER INFORMATION"

logged_users=$(who | wc -l)
echo -e "Currently Logged In Users: $logged_users"

if [ $logged_users -gt 0 ]; then
    echo -e "\nUsername  Terminal  Login Time"
    who | awk '{printf "%-10s %-9s %s %s %s\n", $1, $2, $3, $4, $5}'
fi

# System Services Status (Linux only)
if [ "$OS" = "Linux" ]; then
    print_header "SYSTEM SERVICES"
    
    if command -v systemctl >/dev/null 2>&1; then
        failed_services=$(systemctl --failed --no-legend | wc -l)
        echo -e "Failed Services: $failed_services"
        
        if [ $failed_services -gt 0 ]; then
            echo -e "\nFailed Services:"
            systemctl --failed --no-legend | head -5
        fi
    fi
fi

# Additional System Stats
print_header "ADDITIONAL STATISTICS"

# Last reboot
if [ "$OS" = "Darwin" ]; then
    last_reboot=$(who -b 2>/dev/null | awk '{print $3, $4}')
    if [ -z "$last_reboot" ]; then
        last_reboot=$(last reboot | head -1 | awk '{print $3, $4, $5, $6}')
    fi
else
    last_reboot=$(who -b 2>/dev/null | awk '{print $3, $4}')
    if [ -z "$last_reboot" ]; then
        last_reboot=$(last reboot | head -1 | awk '{print $5, $6, $7, $8}')
    fi
fi

if [ ! -z "$last_reboot" ]; then
    echo -e "Last Reboot: $last_reboot"
fi

# File descriptor usage (Linux only)
if [ "$OS" = "Linux" ] && [ -f /proc/sys/fs/file-nr ]; then
    fd_info=$(cat /proc/sys/fs/file-nr)
    fd_used=$(echo $fd_info | awk '{print $1}')
    fd_max=$(echo $fd_info | awk '{print $3}')
    fd_percent=$((fd_used * 100 / fd_max))
    echo -e "File Descriptors: $fd_used / $fd_max ($fd_percent%)"
fi

# Current date and time
echo -e "\nReport generated at: $(date)"

echo -e "\n================================"
echo -e "Server Statistics Complete"
echo -e "================================"

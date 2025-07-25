#!/bin/sh

# Function to log messages with more detail
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_debug() {
    if [ "$LOG_LEVEL" = "VERBOSE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $1"
    fi
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
}

# Signal handler for graceful shutdown
cleanup() {
    log "=== Shutdown signal received ==="
    log "Stopping vsftpd daemon gracefully..."
    
    # Kill vsftpd process if it's running
    if [ -n "$VSFTPD_PID" ]; then
        log "Terminating vsftpd process (PID: $VSFTPD_PID)"
        kill -TERM "$VSFTPD_PID" 2>/dev/null || true
        
        # Wait for process to terminate
        local count=0
        while kill -0 "$VSFTPD_PID" 2>/dev/null && [ $count -lt 10 ]; do
            log_debug "Waiting for vsftpd to terminate... ($count/10)"
            sleep 1
            count=$((count + 1))
        done
        
        # Force kill if still running
        if kill -0 "$VSFTPD_PID" 2>/dev/null; then
            log "Force killing vsftpd process"
            kill -KILL "$VSFTPD_PID" 2>/dev/null || true
        fi
    fi
    
    # Cleanup temporary files
    log_debug "Cleaning up temporary configuration files"
    rm -f /tmp/vsftpd.conf
    
    log "FTP server shutdown complete"
    exit 0
}

# Set up signal handlers
trap cleanup INT TERM

log "=== Starting FTP server configuration ==="
log "Container startup initiated"

# Security check: Don't run if .ssh directory is detected
log "=== Security Check ==="
SSH_DIRS_FOUND=""

# Check common locations for .ssh directories
for ssh_path in "/root/.ssh" "/home/*/.ssh" "/var/ftp/.ssh" "/var/ftp/public/.ssh"; do
    if [ -d "$ssh_path" ] || ls -d $ssh_path 2>/dev/null | grep -q ".ssh"; then
        SSH_DIRS_FOUND="$SSH_DIRS_FOUND $ssh_path"
    fi
done

# Also check recursively in FTP directories for any .ssh folders
if [ -d "/var/ftp" ]; then
    RECURSIVE_SSH=$(find /var/ftp -type d -name ".ssh" 2>/dev/null || true)
    if [ -n "$RECURSIVE_SSH" ]; then
        SSH_DIRS_FOUND="$SSH_DIRS_FOUND $RECURSIVE_SSH"
    fi
fi

if [ -n "$SSH_DIRS_FOUND" ]; then
    log_error "SECURITY ALERT: SSH directories detected!"
    log_error "Found .ssh directories at:$SSH_DIRS_FOUND"
    log_error "FTP server will NOT start to protect SSH key security."
    log_error "Please remove or relocate .ssh directories before running the FTP server."
    log_error "This prevents potential unauthorized access to SSH private keys."
    exit 1
fi

log "Security check passed: No .ssh directories detected in FTP accessible areas"

# Detect external IP using ipify.org service
log "=== IP Detection ==="
if [ -n "$EXTERNAL_IP" ]; then
    DETECTED_IP="$EXTERNAL_IP"
    log "Using provided external IP: $DETECTED_IP"
else
    log "Detecting external IP using https://api.ipify.org..."
    DETECTED_IP=$(curl -s --connect-timeout 10 https://api.ipify.org || echo "")
    if [ -n "$DETECTED_IP" ]; then
        log "Detected external IP: $DETECTED_IP"
    else
        log_error "Failed to detect external IP, will use auto-detection"
        DETECTED_IP=""
    fi
fi

# Create a working copy of the config file
log_debug "Creating working copy of vsftpd configuration"
cp /etc/vsftpd/vsftpd.conf /tmp/vsftpd.conf

# Configure external IP
if [ -n "$DETECTED_IP" ]; then
    log "Setting external IP to: $DETECTED_IP"
    echo "pasv_address=$DETECTED_IP" >> /tmp/vsftpd.conf
    echo "pasv_addr_resolve=NO" >> /tmp/vsftpd.conf
    # Additional Docker networking fixes
    echo "pasv_promiscuous=YES" >> /tmp/vsftpd.conf
    log_debug "Added pasv_address=$DETECTED_IP to configuration"
    log_debug "Added pasv_addr_resolve=NO to prevent IP resolution issues"
    log_debug "Added pasv_promiscuous=YES for Docker networking compatibility"
fi

# Enable comprehensive logging for all FTP activity
log "=== Configuring comprehensive FTP logging ==="
echo "log_ftp_protocol=YES" >> /tmp/vsftpd.conf
echo "syslog_enable=NO" >> /tmp/vsftpd.conf
echo "vsftpd_log_file=/var/log/vsftpd.log" >> /tmp/vsftpd.conf
echo "dual_log_enable=YES" >> /tmp/vsftpd.conf
echo "xferlog_enable=YES" >> /tmp/vsftpd.conf
echo "xferlog_std_format=YES" >> /tmp/vsftpd.conf
echo "xferlog_file=/var/log/xferlog" >> /tmp/vsftpd.conf
echo "session_support=YES" >> /tmp/vsftpd.conf
log "Enabled comprehensive logging: connections, commands, and transfers"

# Configure FTP port
if [ -n "$PORT" ] && [ "$PORT" != "21" ]; then
    log "Setting FTP port to: $PORT"
    sed -i "s/listen_port=.*/listen_port=$PORT/" /tmp/vsftpd.conf
    if ! grep -q "listen_port=" /tmp/vsftpd.conf; then
        echo "listen_port=$PORT" >> /tmp/vsftpd.conf
        log_debug "Added listen_port=$PORT to configuration"
    fi
else
    log "Using default FTP port: 21"
fi

# Configure passive mode
if [ "$PASSIVE_ENABLE" = "NO" ] || [ "$PASSIVE_ENABLE" = "no" ]; then
    log "Disabling passive mode"
    sed -i "s/pasv_enable=.*/pasv_enable=NO/" /tmp/vsftpd.conf
    log_debug "Passive mode disabled in configuration"
else
    log "Enabling passive mode"
    sed -i "s/pasv_enable=.*/pasv_enable=YES/" /tmp/vsftpd.conf
    log_debug "Passive mode enabled in configuration"
fi

# Configure passive port range
if [ -n "$PASSIVE_MIN_PORT" ]; then
    log "Setting passive min port to: $PASSIVE_MIN_PORT"
    sed -i "s/pasv_min_port=.*/pasv_min_port=$PASSIVE_MIN_PORT/" /tmp/vsftpd.conf
    log_debug "Updated pasv_min_port in configuration"
fi

if [ -n "$PASSIVE_MAX_PORT" ]; then
    log "Setting passive max port to: $PASSIVE_MAX_PORT"
    sed -i "s/pasv_max_port=.*/pasv_max_port=$PASSIVE_MAX_PORT/" /tmp/vsftpd.conf
    log_debug "Updated pasv_max_port in configuration"
fi

# Configure local umask
if [ -n "$LOCAL_UMASK" ]; then
    log "Setting local umask to: $LOCAL_UMASK"
    sed -i "s/anon_umask=.*/anon_umask=$LOCAL_UMASK/" /tmp/vsftpd.conf
    log_debug "Updated anon_umask in configuration"
fi

# Configure new parameters
log "=== Configuring additional parameters ==="

# Connection limits
if [ -n "$MAX_CLIENTS" ]; then
    log "Setting max clients to: $MAX_CLIENTS"
    sed -i "s/max_clients=.*/max_clients=$MAX_CLIENTS/" /tmp/vsftpd.conf
fi

if [ -n "$MAX_PER_IP" ]; then
    log "Setting max per IP to: $MAX_PER_IP"
    sed -i "s/max_per_ip=.*/max_per_ip=$MAX_PER_IP/" /tmp/vsftpd.conf
fi

# Timeouts
if [ -n "$IDLE_TIMEOUT" ]; then
    log "Setting idle timeout to: $IDLE_TIMEOUT seconds"
    sed -i "s/idle_session_timeout=.*/idle_session_timeout=$IDLE_TIMEOUT/" /tmp/vsftpd.conf
fi

if [ -n "$DATA_TIMEOUT" ]; then
    log "Setting data timeout to: $DATA_TIMEOUT seconds"
    sed -i "s/data_connection_timeout=.*/data_connection_timeout=$DATA_TIMEOUT/" /tmp/vsftpd.conf
fi

# Transfer rate limits
if [ -n "$MAX_UPLOAD_RATE" ] && [ "$MAX_UPLOAD_RATE" != "0" ]; then
    log "Setting max upload rate to: $MAX_UPLOAD_RATE bytes/sec"
    echo "anon_max_rate=$MAX_UPLOAD_RATE" >> /tmp/vsftpd.conf
fi

if [ -n "$MAX_DOWNLOAD_RATE" ] && [ "$MAX_DOWNLOAD_RATE" != "0" ]; then
    log "Setting max download rate to: $MAX_DOWNLOAD_RATE bytes/sec"
    echo "local_max_rate=$MAX_DOWNLOAD_RATE" >> /tmp/vsftpd.conf
fi

# File size limit
if [ -n "$MAX_FILE_SIZE" ] && [ "$MAX_FILE_SIZE" != "0" ]; then
    log "Setting max file size to: $MAX_FILE_SIZE bytes"
    echo "file_open_mode=0644" >> /tmp/vsftpd.conf
    echo "max_file_size=$MAX_FILE_SIZE" >> /tmp/vsftpd.conf
fi

# File operations
if [ "$ALLOW_DELETE" = "YES" ] || [ "$ALLOW_DELETE" = "yes" ]; then
    log "Enabling file deletion for anonymous users"
    echo "anon_other_write_enable=YES" >> /tmp/vsftpd.conf
else
    log "File deletion disabled for anonymous users"
    sed -i "s/anon_other_write_enable=.*/anon_other_write_enable=NO/" /tmp/vsftpd.conf
fi

if [ "$ALLOW_OVERWRITE" = "NO" ] || [ "$ALLOW_OVERWRITE" = "no" ]; then
    log "Disabling file overwrite"
    echo "deny_file={*.tmp,*.temp}" >> /tmp/vsftpd.conf
else
    log "File overwrite enabled"
fi

# Directory umask
if [ -n "$DIR_UMASK" ]; then
    log "Setting directory umask to: $DIR_UMASK"
    echo "local_umask=$DIR_UMASK" >> /tmp/vsftpd.conf
fi

# Listen address
if [ -n "$LISTEN_ADDRESS" ]; then
    log "Setting listen address to: $LISTEN_ADDRESS"
    echo "listen_address=$LISTEN_ADDRESS" >> /tmp/vsftpd.conf
fi

# ASCII mode
if [ "$ASCII_MODE" = "NO" ] || [ "$ASCII_MODE" = "no" ]; then
    log "Disabling ASCII mode"
    echo "ascii_upload_enable=NO" >> /tmp/vsftpd.conf
    echo "ascii_download_enable=NO" >> /tmp/vsftpd.conf
else
    log "ASCII mode enabled"
    echo "ascii_upload_enable=YES" >> /tmp/vsftpd.conf
    echo "ascii_download_enable=YES" >> /tmp/vsftpd.conf
fi

# Sendfile
if [ "$USE_SENDFILE" = "NO" ] || [ "$USE_SENDFILE" = "no" ]; then
    log "Disabling sendfile"
    echo "use_sendfile=NO" >> /tmp/vsftpd.conf
else
    log "Sendfile enabled for better performance"
    echo "use_sendfile=YES" >> /tmp/vsftpd.conf
fi

log "=== Setting up directory structure ==="

# Fix directory permissions for vsftpd security requirements
log_debug "Setting FTP root directory permissions"
chown root:root /var/ftp
chmod 555 /var/ftp  # Read and execute only, not writable
log "FTP root directory (/var/ftp) set to read-only (owner: root:root, permissions: 555)"

# Make sure public directory exists and is writable for uploads
log_debug "Creating and configuring public upload directory"
mkdir -p /var/ftp/public
chown ftp:ftp /var/ftp/public
chmod 755 /var/ftp/public  # Writable for uploads
log "Upload directory (/var/ftp/public) created and set to writable (owner: ftp:ftp, permissions: 755)"

# Create custom banner
log "=== Creating connection banner ==="
if [ -n "$BANNER_TEXT" ]; then
    SIMPLE_BANNER="$BANNER_TEXT"
else
    if [ -n "$DETECTED_IP" ]; then
        SIMPLE_BANNER="Welcome to Anonymous FTP! Server: $DETECTED_IP:${PORT:-21} | Upload to: /public/ | User: anonymous"
    else
        SIMPLE_BANNER="Welcome to Anonymous FTP! Upload to: /public/ | User: anonymous"
    fi
fi

# Use simple single-line banner to avoid config parsing issues
echo "ftpd_banner=$SIMPLE_BANNER" >> /tmp/vsftpd.conf
log "Custom banner created: $SIMPLE_BANNER"

# Create detailed welcome file for FTP clients that support it
WELCOME_FILE="/var/ftp/.message"
if [ -n "$DETECTED_IP" ]; then
    cat > "$WELCOME_FILE" << EOF
Welcome to Anonymous FTP Server!

Connection Guide:
- Server IP: $DETECTED_IP
- Port: ${PORT:-21}
- Username: anonymous
- Password: (any email or leave blank)
- Upload directory: /public/

Example FTP URL: ftp://anonymous@$DETECTED_IP:${PORT:-21}/public/

Happy file sharing!
EOF
else
    cat > "$WELCOME_FILE" << EOF
Welcome to Anonymous FTP Server!

Connection Guide:
- Username: anonymous  
- Password: (any email or leave blank)
- Upload directory: /public/

Happy file sharing!
EOF
fi

chown ftp:ftp "$WELCOME_FILE"
chmod 644 "$WELCOME_FILE"
echo "message_file=.message" >> /tmp/vsftpd.conf
log "Detailed welcome file created at $WELCOME_FILE"

# Verify directory structure
log "=== Directory structure verification ==="
log_debug "Listing /var/ftp contents:"
ls -la /var/ftp/ | while read line; do
    log_debug "  $line"
done

log "=== Configuration Summary ==="
log "Anonymous FTP enabled with upload permissions"
log "FTP root directory: /var/ftp (read-only)"
log "Upload directory: /var/ftp/public (writable)"
log "Configuration details:"
log "  External IP: ${DETECTED_IP:-'auto-detect'}"
log "  FTP Port: ${PORT}"
log "  Passive Mode: ${PASSIVE_ENABLE}"
log "  Passive Port Range: ${PASSIVE_MIN_PORT}-${PASSIVE_MAX_PORT}"
log "  Local Umask: ${LOCAL_UMASK}"
log "  Max Clients: ${MAX_CLIENTS}"
log "  Max Per IP: ${MAX_PER_IP}"
log "  Idle Timeout: ${IDLE_TIMEOUT}s"
log "  Data Timeout: ${DATA_TIMEOUT}s"
log "  Upload Rate Limit: ${MAX_UPLOAD_RATE:-unlimited}"
log "  Download Rate Limit: ${MAX_DOWNLOAD_RATE:-unlimited}"
log "  Max File Size: ${MAX_FILE_SIZE:-unlimited}"
log "  Allow Delete: ${ALLOW_DELETE}"
log "  Allow Overwrite: ${ALLOW_OVERWRITE}"

# Show final configuration file (for debugging)
if [ "$LOG_LEVEL" = "VERBOSE" ]; then
    log "=== Final vsftpd configuration ==="
    log_debug "Configuration file contents:"
    cat /tmp/vsftpd.conf | while read line; do
        log_debug "  $line"
    done
fi

# Start vsftpd in foreground mode
log "=== Starting vsftpd daemon ==="

# Validate configuration before starting
log_debug "Validating vsftpd configuration..."
if ! /usr/sbin/vsftpd /tmp/vsftpd.conf -t 2>/dev/null; then
    log_error "Configuration validation failed! Checking for common issues..."
    /usr/sbin/vsftpd /tmp/vsftpd.conf -t 2>&1 | while read error_line; do
        log_error "Config error: $error_line"
    done
else
    log_debug "Configuration validation passed"
fi

# Ensure log directory exists with proper permissions
log_debug "Setting up logging infrastructure"
mkdir -p /var/log
touch /var/log/vsftpd.log
touch /var/log/xferlog
chmod 644 /var/log/vsftpd.log /var/log/xferlog
chown root:root /var/log/vsftpd.log /var/log/xferlog

log "vsftpd starting in foreground mode..."
if [ -n "$DETECTED_IP" ]; then
    log "FTP server ready! Connect to: ftp://anonymous@$DETECTED_IP:${PORT:-21}/public/"
else
    log "FTP server ready! Connect with username 'anonymous' to upload files to /public/"
fi
log "Ready to accept FTP connections"

# Start vsftpd in background and capture PID
/usr/sbin/vsftpd /tmp/vsftpd.conf &
VSFTPD_PID=$!

log "vsftpd started with PID: $VSFTPD_PID"

# Simple log monitoring function
monitor_ftp_logs() {
    # Wait for vsftpd to start and potentially create log files
    sleep 3
    
    log "Starting comprehensive FTP activity monitoring..."
    
    # Create log files if they don't exist
    touch /var/log/vsftpd.log
    touch /var/log/xferlog
    
    # Monitor main vsftpd log for connections, commands, and protocol activity
    log_debug "Monitoring /var/log/vsftpd.log for connections and commands"
    tail -f /var/log/vsftpd.log 2>/dev/null | while read line; do
        if [ -n "$line" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FTP-ACTIVITY] $line"
        fi
    done &
    VSFTPD_LOG_PID=$!
    
    # Monitor xferlog for file transfers
    log_debug "Monitoring /var/log/xferlog for file transfers"
    tail -f /var/log/xferlog 2>/dev/null | while read line; do
        if [ -n "$line" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TRANSFER] $line"
        fi
    done &
    XFERLOG_PID=$!
    
    # Also monitor system messages for any vsftpd-related entries
    if [ -f "/var/log/messages" ]; then
        log_debug "Monitoring /var/log/messages for system-level FTP events"
        tail -f /var/log/messages 2>/dev/null | grep -i vsftpd | while read line; do
            if [ -n "$line" ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SYSTEM] $line"
            fi
        done &
        MESSAGES_PID=$!
    fi
    
    log "FTP activity monitoring started - you should see all connections, commands, and transfers"
    log_debug "Log monitoring PIDs: vsftpd=${VSFTPD_LOG_PID}, xferlog=${XFERLOG_PID}"
}

# Start comprehensive FTP activity monitoring (always enabled)
monitor_ftp_logs

# Wait for vsftpd process to finish
wait $VSFTPD_PID 
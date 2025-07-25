#!/bin/sh

# Function to log messages with more detail
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_debug() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
}

log "=== Starting FTP server configuration ==="
log "Container startup initiated"

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
    log_debug "Added pasv_address=$DETECTED_IP to configuration"
fi

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
if [ "$LOG_LEVEL" = "DEBUG" ] || [ "$LOG_LEVEL" = "VERBOSE" ]; then
    log "=== Final vsftpd configuration ==="
    log_debug "Configuration file contents:"
    cat /tmp/vsftpd.conf | while read line; do
        log_debug "  $line"
    done
fi

# Start vsftpd in foreground mode
log "=== Starting vsftpd daemon ==="
log "vsftpd starting in foreground mode..."
if [ -n "$DETECTED_IP" ]; then
    log "FTP server ready! Connect to: ftp://anonymous@$DETECTED_IP:${PORT:-21}/public/"
else
    log "FTP server ready! Connect with username 'anonymous' to upload files to /public/"
fi
log "Ready to accept FTP connections"
exec /usr/sbin/vsftpd /tmp/vsftpd.conf 
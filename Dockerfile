FROM alpine:latest

# Install vsftpd and required packages
RUN apk add --no-cache vsftpd curl

# Create FTP directory structure with correct permissions
RUN mkdir -p /var/ftp/public && \
    chown root:root /var/ftp && \
    chmod 555 /var/ftp && \
    chown ftp:ftp /var/ftp/public && \
    chmod 755 /var/ftp/public

# Copy configuration files
COPY vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY entrypoint.sh /entrypoint.sh

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# Create log directory
RUN mkdir -p /var/log/vsftpd

# Expose FTP ports
EXPOSE 21

# Set environment variables with defaults (removed FTP_ prefix)
ENV EXTERNAL_IP=""
ENV PORT=21
ENV PASSIVE_ENABLE=YES
ENV PASSIVE_MIN_PORT=30000
ENV PASSIVE_MAX_PORT=30100
ENV LOCAL_UMASK=022

# New proposed environment variables
ENV MAX_CLIENTS=50
ENV MAX_PER_IP=5
ENV IDLE_TIMEOUT=600
ENV DATA_TIMEOUT=120
ENV BANNER_TEXT=""
ENV MAX_UPLOAD_RATE=0
ENV MAX_DOWNLOAD_RATE=0
ENV MAX_FILE_SIZE=0
ENV ALLOW_DELETE=NO
ENV ALLOW_OVERWRITE=YES
ENV DIR_UMASK=022
ENV LOG_LEVEL=NORMAL
ENV LOG_UPLOADS=YES
ENV LOG_DOWNLOADS=YES
ENV LISTEN_ADDRESS=""
ENV ASCII_MODE=YES
ENV USE_SENDFILE=YES

# Run entrypoint script
ENTRYPOINT ["/entrypoint.sh"] 
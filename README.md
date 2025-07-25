# FTP Anonymous Server (Alpine-based)

A lightweight Docker container running an FTP server with anonymous access for file uploads and downloads.

**Docker Hub Repository**: [andspace/ftp-anon](https://hub.docker.com/repository/docker/andspace/ftp-anon/general)  
**GitHub Repository**: [logical-and/ftp-anon](https://github.com/logical-and/ftp-anon)

## Quick Start

### Easiest - From Docker Hub

```bash
PORT=2121 && docker run -it --rm -p $PORT:$PORT -p 6000-6100:6000-6100 -v $(pwd):/var/ftp/public -e PORT=$PORT -e PASSIVE_MIN_PORT=6000 -e PASSIVE_MAX_PORT=6100 andspace/ftp-anon
```

### Build Yourself (Auto IP Detection)

```bash
docker build -t anonymous-ftp . && docker run -it --rm -p 21:21 -p 30000-30100:30000-30100 anonymous-ftp
```

### With Custom Options

```bash
docker build -t anonymous-ftp . && docker run -it --rm \
  -p 2121:2121 -p 35000-35100:35000-35100 \
  -e EXTERNAL_IP=192.168.1.100 \
  -e PORT=2121 \
  -e PASSIVE_MIN_PORT=35000 \
  -e PASSIVE_MAX_PORT=35100 \
  anonymous-ftp
```

### Using Docker Compose

```bash
docker-compose up -d
```

## Features

- **Anonymous Access**: No authentication required
- **Upload/Download**: Anonymous users can list, upload, and download files
- **Alpine-based**: Minimal footprint using Alpine Linux
- **Auto IP Detection**: Automatically detects external IP using [https://api.ipify.org](https://api.ipify.org)
- **Smart Banner**: Shows connection guide with detected IP and FTP URL
- **Highly Configurable**: All settings via environment variables
- **Verbose Logging**: Detailed logs output to stdout for debugging
- **Self-contained**: No external directories required

## Environment Variables

### Core Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `EXTERNAL_IP` | auto-detect | External IP address for passive mode |
| `PORT` | 21 | FTP control port |
| `PASSIVE_ENABLE` | YES | Enable/disable passive mode (YES/NO) |
| `PASSIVE_MIN_PORT` | 30000 | Minimum passive mode port |
| `PASSIVE_MAX_PORT` | 30100 | Maximum passive mode port |
| `LOCAL_UMASK` | 022 | File creation umask |

### Connection & Security
| Variable | Default | Description |
|----------|---------|-------------|
| `MAX_CLIENTS` | 50 | Maximum simultaneous connections |
| `MAX_PER_IP` | 5 | Maximum connections from same IP |
| `IDLE_TIMEOUT` | 600 | Session idle timeout (seconds) |
| `DATA_TIMEOUT` | 120 | Data connection timeout (seconds) |
| `LISTEN_ADDRESS` | all | Specific IP to bind to |

### Transfer Limits
| Variable | Default | Description |
|----------|---------|-------------|
| `MAX_UPLOAD_RATE` | 0 | Upload speed limit (bytes/sec, 0=unlimited) |
| `MAX_DOWNLOAD_RATE` | 0 | Download speed limit (bytes/sec, 0=unlimited) |
| `MAX_FILE_SIZE` | 0 | Maximum file size for uploads (bytes, 0=unlimited) |

### File Operations
| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOW_DELETE` | YES | Allow anonymous users to delete files (YES/NO) |
| `ALLOW_OVERWRITE` | YES | Allow overwriting existing files (YES/NO) |
| `DIR_UMASK` | 022 | Directory creation umask |

### Logging & Display
| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | VERBOSE | Log verbosity (MINIMAL/VERBOSE) |
| `BANNER_TEXT` | auto-generated | Custom welcome banner message |

### Performance
| Variable | Default | Description |
|----------|---------|-------------|
| `ASCII_MODE` | YES | Enable ASCII transfer mode (YES/NO) |
| `USE_SENDFILE` | YES | Use sendfile for better performance (YES/NO) |

## Usage

1. **Connect to FTP**: Use any FTP client and connect to the server IP on port 2121 (or 21 if using defaults)
2. **Anonymous Login**: Username: `anonymous`, Password: (any email or leave blank)
3. **Upload Files**: Navigate to `/public` directory to upload files
4. **Download Files**: Browse and download any files in the FTP directory

## Auto-Generated Banner

When you connect, you'll see a helpful banner like:

```
Welcome to FTP Anonymous Server!

Connection Guide:
- Server IP: 203.0.113.1
- Port: 2121
- Username: anonymous
- Password: (any email or leave blank)
- Upload directory: /public/

Example FTP URL: ftp://anonymous@203.0.113.1:2121/public/

Happy file sharing!
```

## Example FTP Client Commands

```bash
# Using command-line FTP client
ftp <server-ip> 2121
# Username: anonymous
# Password: (press enter or type any email)

# List files
ls

# Change to upload directory
cd public

# Upload a file
put myfile.txt

# Download a file
get somefile.txt
```

## Directory Structure

- `/var/ftp/` - FTP root directory (read-only)
- `/var/ftp/public/` - Upload directory for anonymous users (writable)

## Ports

- **2121**: FTP control port (when using Docker Hub image)
- **6000-6100**: Passive mode data ports (when using Docker Hub image)
- **21**: Default FTP control port (when building yourself)
- **30000-30100**: Default passive mode data ports (when building yourself)

## IP Detection

The server automatically detects your external IP using the [https://api.ipify.org](https://api.ipify.org) service and includes it in the welcome banner. You can override this by setting the `EXTERNAL_IP` environment variable.

## Logging

The container provides verbose logging with different log levels:
- **[INFO]**: General operational information
- **[DEBUG]**: Detailed debugging information including configuration details
- **[ERROR]**: Error messages

All logs include timestamps and are output to stdout for easy monitoring with `docker logs`.

## Security Notes

- This server allows anonymous access with upload capabilities
- Intended for development/testing environments
- For production use, consider additional security measures
- No authentication or encryption is provided
- The FTP root directory is read-only for security (vsftpd requirement)
- Only the `public/` subdirectory allows uploads

## Building

```bash
docker build -t anonymous-ftp .
```

## Logs

All logs are output to stdout and can be viewed with:

```bash
docker logs <container-name>
```

For real-time log monitoring:

```bash
docker logs -f <container-name>
``` 
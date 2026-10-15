# show-tktprint-logs.sh

A utility script for displaying Docker container logs from the tktprint service during batch printing functional testing.

## Overview

The `show-tktprint-logs.sh` script provides an easy way to monitor the tktprint Docker container logs without having to navigate directories or remember docker-compose commands. This is particularly useful during functional testing of batch printing operations.

## Location

```
tktprint-batch/show-tktprint-logs.sh
```

## Usage

### Basic Usage

```bash
# Show last 100 lines of tktprint logs (default)
./show-tktprint-logs.sh

# Show last 50 lines
./show-tktprint-logs.sh -n 50

# Follow logs in real-time
./show-tktprint-logs.sh -f

# Follow logs with specific tail count
./show-tktprint-logs.sh -f -n 200
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-f`, `--follow` | Follow log output in real-time (like `tail -f`) | false |
| `-n`, `--tail` | Number of lines to show from the end of logs | 100 |
| `-h`, `--help` | Display help message and usage information | - |

## Features

- **Automatic Directory Navigation**: The script automatically navigates to the correct site root directory where `docker-compose.yml` is located
- **Error Handling**: Checks for docker-compose availability and required files
- **Flexible Output**: Supports both static log viewing and real-time following
- **Help Documentation**: Built-in help with usage examples

## Prerequisites

- Docker and docker-compose must be installed and available in PATH
- The script must be run from within the Theater Wit development environment
- The tktprint Docker service must be defined in the main docker-compose.yml

## Examples

### Debugging Batch Printing Issues

```bash
# Start following logs before running a batch print job
./show-tktprint-logs.sh -f

# In another terminal, trigger your batch printing operation
# Watch the logs in real-time to see what happens
```

### Checking Recent Activity

```bash
# Quick check of recent log entries
./show-tktprint-logs.sh -n 20

# More comprehensive recent history
./show-tktprint-logs.sh -n 500
```

### Functional Testing Workflow

1. Start the script in follow mode: `./show-tktprint-logs.sh -f`
2. Execute your batch printing test cases
3. Monitor the logs for expected behavior, errors, or unexpected output
4. Press Ctrl+C to stop following when done

## Technical Details

The script:
- Locates the site root directory relative to its own location
- Uses `docker-compose logs` command with the `tktprint` service name
- Passes through tail count and follow flags to docker-compose
- Provides user-friendly error messages for common issues

## Troubleshooting

**Error: "docker-compose is not installed or not in PATH"**
- Ensure Docker Compose is properly installed
- Check that `docker-compose` command is available in your terminal

**Error: "docker-compose.yml not found"**
- Verify you're running the script from the correct location
- Ensure the main site docker-compose.yml file exists

**No output or "service not found" errors**
- Confirm the tktprint service is defined in docker-compose.yml
- Check if the tktprint container is running: `docker-compose ps`
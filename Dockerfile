# Use Ruby 3.2.2 on ARM-compatible base image (similar to Raspberry Pi)
FROM ruby:3.2.2-slim-bookworm

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libsqlite3-dev \
    nodejs \
    git \
    curl \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'false' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy application code (this will be overridden by volume mount in development)
COPY . .

# Create necessary directories
RUN mkdir -p log tmp/pids tmp/cache tmp/sockets public/assets && \
    chmod -R 755 log tmp

# Create a non-root user to run the app
RUN useradd -m -s /bin/bash appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 3000

# Default command (can be overridden in docker-compose)
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
#!/bin/bash
set -e

echo "Upgrading tktprint to Ruby 3.2.2 and Rails 6.1.7..."

# Install Ruby 3.2.2 if not already installed
if ! rbenv versions | grep -q "3.2.2"; then
  echo "Installing Ruby 3.2.2..."
  rbenv install 3.2.2
fi

# Set local Ruby version
rbenv local 3.2.2

# Remove old bundler versions and install the latest
echo "Updating Bundler..."
gem uninstall bundler --all
gem install bundler --version 2.6.1
rbenv rehash

# Install dependencies
bundle _2.6.1_ install

# Database operations
echo "Running database operations..."
bundle exec rails db:environment:set RAILS_ENV=development
bundle exec rails generate delayed_job:active_record
bundle exec rails db:migrate

# Clear tmp files
echo "Clearing temporary files..."
bundle exec rails tmp:clear
bundle exec rails log:clear

echo "Upgrade completed! Please start your services:"
echo "1. Start Rails with Puma: bundle exec rails s -e production"
echo "2. Start Delayed Job worker: bundle exec bin/delayed_job start"

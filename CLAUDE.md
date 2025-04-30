# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands
- `bundle exec rake test` - Run all tests
- `bundle exec rake test TEST=test/path/to/file_test.rb` - Run a single test file
- `bundle exec rake test TEST=test/path/to/file_test.rb TESTOPTS="--name=test_method_name"` - Run a specific test
- `bundle exec rubocop` - Run linting
- `bundle exec brakeman` - Run security scanning

## Code Style Guidelines
- Follow Rails Omakase styling (via rubocop-rails-omakase)
- Use 2-space indentation
- Sort imports alphabetically
- Use snake_case for variables and methods
- Use CamelCase for classes and modules
- Use double quotes for strings
- Include explicit return types in method comments
- Handle errors with appropriate Rails patterns
- Use FactoryBot for test fixtures
- Write comprehensive tests for models and controllers

## Project Structure
- Follow standard Rails MVC architecture
- Place business logic in models or service objects
- Keep controllers thin with RESTful actions
- Use JavaScript for interactive UI components via Stimulus
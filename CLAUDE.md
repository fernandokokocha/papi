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

## Design — White & Sky palette (Tailwind CSS v4)

### Nav
- Background: `bg-sky-900`
- Logo: `text-white font-bold`
- Email/user text: `text-white`
- Nav button: `bg-sky-500 hover:bg-sky-400 text-white`

### Page
- Background: `bg-gray-50` (page), `bg-white` (panels/cards)
- Layout border: `border-gray-200`
- Primary text: `text-gray-900`
- Secondary text: `text-gray-500`

### Buttons
- **Primary**: `bg-sky-600 hover:bg-sky-700 text-white`
- **Secondary**: `bg-white text-gray-700 border border-gray-300 hover:bg-gray-50`
- **Merge**: `bg-emerald-600 hover:bg-emerald-700 text-white`
- **Reject**: `bg-red-600 hover:bg-red-700 text-white`

### State badges
- **Open**: `bg-yellow-50 text-yellow-700 border border-yellow-200 rounded-full`
- **Merged**: `bg-emerald-50 text-emerald-700 border border-emerald-200 rounded-full`
- **Rejected**: `bg-red-50 text-red-700 border border-red-200 rounded-full`

### Forms
- Input border: `border-gray-300`
- Placeholder: `placeholder-gray-400`
- Focus: `focus:outline-none focus:ring-2 focus:ring-sky-500`

### Monospace / code areas
- `bg-gray-100 text-gray-800 font-mono`
namespace :dev do
  desc "Full dev setup: reset DB, prepare test, load fixtures, patch references"
  task setup: :environment do
    puts "Resetting DB..."
    Rake::Task["db:migrate:reset"].invoke

    puts "Loading fixtures..."
    Rake::Task["db:fixtures:load"].invoke

    puts "Filling fixture dependencies..."
    Rake::Task["dev:fill_fixtures_dependencies"].invoke

    puts "✅ Dev setup complete!"
  end
end

namespace :dev do
  desc "Full dev setup: reset the database, load the fixtures, import the Petstore document"
  task setup: :environment do
    puts "Resetting DB..."
    Rake::Task["db:migrate:reset"].invoke

    puts "Loading fixtures..."
    Rake::Task["db:fixtures:load"].invoke

    puts "Importing the Petstore document..."
    Rake::Task["dev:import_petstore"].invoke

    puts "✅ Dev setup complete! Sign in as mira@drugowcy.dev (or tomek, anka, piotr) with the password \"password\"."
  end
end

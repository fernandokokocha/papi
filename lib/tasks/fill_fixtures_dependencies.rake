namespace :dev do
  desc "Load fixtures and patch circular dependencies"
  task fill_fixtures_dependencies: :environment do
    puts "Be aware that this task should be run AFTER loading fixtures into the dev database"

    Candidate.all.sort_by(&:order).each do |candidate|
      next if candidate.order == 1
      if candidate.base_version
        puts "Candidate #{candidate.name} already as base version, skipping"
        next
      end
      project = candidate.project
      version = project.versions.find_by(name: "v#{candidate.order - 1}")
      puts "Updating candidate #{candidate.name} with base version #{version.name}"
      candidate.update!(base_version: version)
      puts "Done"
    end

    puts "All updated."
  end
end

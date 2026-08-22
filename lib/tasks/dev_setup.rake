namespace :dev do
  desc "Full dev setup: reset DB, prepare test, load fixtures, patch references"
  task setup: :environment do
    puts "Resetting DB..."
    Rake::Task["db:migrate:reset"].invoke

    puts "Loading fixtures..."
    Rake::Task["db:fixtures:load"].invoke

    puts "Filling fixture dependencies..."
    Rake::Task["dev:fill_fixtures_dependencies"].invoke

    puts "Opening a candidate..."
    Rake::Task["dev:open_candidate"].invoke

    puts "✅ Dev setup complete!"
  end
end

namespace :dev do
  desc "Cut an open candidate off the latest version, so the open state has something to show"
  task open_candidate: :environment do
    project = Project.first
    base = project.latest_version
    author = User.find_by(email_address: "two@example.com")

    candidate = project.candidates.create!(
      name: "rc#{project.candidates.maximum(:order) + 1}",
      order: project.candidates.maximum(:order) + 1,
      base_version: base,
      author: author,
      aasm_state: "open",
      created_at: 3.days.ago
    )

    version = base.amoeba_dup
    version.order = 1
    version.name = "#{candidate.name}-v1"
    version.candidate = candidate
    version.release_notes = "Webhook deliveries become inspectable: /webhooks/deliveries lists the last attempts, and a webhook now carries the secret it signs with."
    version.created_at = candidate.created_at

    version.entities.find { |entity| entity.name == "Webhook" }.tap do |webhook|
      webhook.root = "{id:number,url:string,events:[string],secret:string,active:boolean}"
    end

    version.endpoints.build(
      path: "/webhooks/deliveries",
      http_verb: "verb_get",
      input: "",
      auth: "ServiceKey",
      responses_attributes: [
        { code: "200", output: "{total:number,items:[{id:number,status:number,at:string}]}" },
        { code: "403", output: "Error" }
      ]
    )

    version.save!

    User.find_by(email_address: "one@example.com").tap do |approver|
      candidate.approvals.create!(user: approver, created_at: 1.day.ago)
    end

    puts "Opened candidate #{candidate.name} (#{version.name})"
  end
end

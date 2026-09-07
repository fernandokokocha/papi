module Blog
  class Post
    DIRECTORY = Rails.root.join("content/blog")
    KRAMDOWN = { syntax_highlighter: :rouge, syntax_highlighter_opts: { formatter: "HTML" } }.freeze

    def self.all(directory = DIRECTORY)
      Dir.children(directory).grep(/\.md\z/).sort.reverse.map { |file| new(directory.join(file)) }
    end

    def self.find(slug, directory = DIRECTORY)
      all(directory).find { |post| post.slug == slug } ||
        raise(ActiveRecord::RecordNotFound, "No blog post #{slug.inspect}")
    end

    def initialize(path)
      @path = path
    end

    def slug
      basename.delete_prefix("#{date_string}-")
    end

    def date
      Date.parse(date_string)
    end

    def title
      front_matter.fetch("title")
    end

    def summary
      front_matter.fetch("summary")
    end

    def body_html
      Kramdown::Document.new(body, **KRAMDOWN).to_html.html_safe
    end

    private
      attr_reader :path

      def basename
        path.basename(".md").to_s
      end

      def date_string
        basename[0, 10]
      end

      def front_matter
        YAML.safe_load(sections.second)
      end

      def body
        sections.third
      end

      def sections
        @sections ||= path.read.split(/^---\s*$\n/, 3)
      end
  end
end

class AuthMethod < ApplicationRecord
  KINDS = %w[bearer basic].freeze

  attr_accessor :annotation
  attr_accessor :previous

  belongs_to :version

  scope :sort_by_name, -> { order(:name) }

  def identity_name
    name
  end

  def sort_name
    name
  end

  def differs_from?(previous)
    previous.kind != kind || previous.note != note
  end

  def same_contract_as?(other)
    name == other.name && kind == other.kind
  end

  SCHEME_BY_KIND = { "bearer" => "Bearer", "basic" => "Basic" }.freeze

  def challenge
    SCHEME_BY_KIND.fetch(kind)
  end

  # The mock has no credentials to check against, so it checks the shape of the
  # header and takes any value: enough to prove a client wired its auth up.
  def satisfied_by?(authorization_header)
    /\A#{challenge} \S+\z/.match?(authorization_header.to_s)
  end

  amoeba do
    enable
  end
end

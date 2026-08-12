require "rails_helper"

describe DiffAuth::FromAuth do
  def auth(name, kind, note = "")
    AuthMethod.new(name: name, kind: kind, note: note)
  end

  describe "#any_changes?" do
    it "is false when both sides name the same method" do
      diff = DiffAuth::FromAuth.new(auth("UserToken", "bearer"), auth("UserToken", "bearer"))
      expect(diff.any_changes?).to be(false)
    end

    it "is false when neither side declares auth" do
      expect(DiffAuth::FromAuth.new(nil, nil).any_changes?).to be(false)
    end

    it "is true when an endpoint switches to another method" do
      diff = DiffAuth::FromAuth.new(auth("UserToken", "bearer"), auth("AdminBasic", "basic"))
      expect(diff.any_changes?).to be(true)
    end

    # A reworded note is documentation, not contract: it moves the auth section,
    # never the endpoints pointing at it.
    it "is false when only the method's note was rewritten" do
      diff = DiffAuth::FromAuth.new(
        auth("UserToken", "bearer", "Token from POST /sessions"),
        auth("UserToken", "bearer", "Token from POST /login")
      )
      expect(diff.any_changes?).to be(false)
    end

    it "is true when the method keeps its name but changes kind" do
      diff = DiffAuth::FromAuth.new(auth("UserToken", "bearer"), auth("UserToken", "basic"))
      expect(diff.any_changes?).to be(true)
    end
  end

  describe "the rendered lines" do
    it "marks an endpoint that gained auth as added on both sides" do
      diff = DiffAuth::FromAuth.new(nil, auth("UserToken", "bearer"))

      expect(diff.before_line.whole_line).to eq("none")
      expect(diff.after_line.whole_line).to eq("UserToken bearer")
      expect(diff.after_line.change).to eq("added")
    end

    it "marks an endpoint that lost auth as removed" do
      diff = DiffAuth::FromAuth.new(auth("UserToken", "bearer"), nil)

      expect(diff.before_line.whole_line).to eq("UserToken bearer")
      expect(diff.after_line.whole_line).to eq("none")
      expect(diff.before_line.change).to eq("removed")
    end

    it "marks a swapped method as type_changed on both sides" do
      diff = DiffAuth::FromAuth.new(auth("UserToken", "bearer"), auth("AdminBasic", "basic"))

      expect(diff.before_line.change).to eq("type_changed")
      expect(diff.after_line.change).to eq("type_changed")
    end
  end
end

describe Endpoint, "#differs_from? on auth" do
  let!(:group) { Group.create!(name: "g") }
  let!(:project) { Project.create!(name: "p", group: group) }
  let!(:before_version) { FactoryBot.create(:version, project: project, name: "v1") }
  let!(:after_version) { FactoryBot.create(:version, project: project, name: "v2") }

  def endpoint_in(version, auth)
    FactoryBot.create(:endpoint, version: version, path: "/users", http_verb: "verb_get",
                                 note: "", input: "", auth: auth)
  end

  it "sees an endpoint that started requiring auth" do
    before = endpoint_in(before_version, "")
    FactoryBot.create(:auth_method, version: after_version, name: "UserToken", kind: "bearer")
    after = endpoint_in(after_version, "UserToken")

    expect(after.reload.differs_from?(before.reload)).to eq(true)
  end

  # The endpoint's own row did not move, but what its clients must send did.
  it "sees the method it names change kind underneath it" do
    FactoryBot.create(:auth_method, version: before_version, name: "UserToken", kind: "bearer")
    before = endpoint_in(before_version, "UserToken")
    FactoryBot.create(:auth_method, version: after_version, name: "UserToken", kind: "basic")
    after = endpoint_in(after_version, "UserToken")

    expect(after.reload.differs_from?(before.reload)).to eq(true)
  end

  it "leaves an endpoint alone when its method only gained a note" do
    FactoryBot.create(:auth_method, version: before_version, name: "UserToken", kind: "bearer", note: "")
    before = endpoint_in(before_version, "UserToken")
    FactoryBot.create(:auth_method, version: after_version, name: "UserToken", kind: "bearer", note: "Expires in 24h")
    after = endpoint_in(after_version, "UserToken")

    expect(after.reload.differs_from?(before.reload)).to eq(false)
  end
end

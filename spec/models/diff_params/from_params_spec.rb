require "rails_helper"

describe DiffParams::FromParams do
  def param(name, kind)
    EndpointParam.new(name: name, kind: kind)
  end

  describe "#any_changes?" do
    it "is false when both sides hold the same kinds" do
      diff = DiffParams::FromParams.new([ param("id", "number") ], [ param("id", "number") ])
      expect(diff.any_changes?).to be(false)
    end

    it "is true when a kind changes" do
      diff = DiffParams::FromParams.new([ param("id", "string") ], [ param("id", "number") ])
      expect(diff.any_changes?).to be(true)
    end

    it "is false when neither side has params" do
      expect(DiffParams::FromParams.new([], []).any_changes?).to be(false)
    end
  end

  describe "#after_rows" do
    it "marks an unchanged param as no_change" do
      diff = DiffParams::FromParams.new([ param("id", "number") ], [ param("id", "number") ])
      expect(diff.after_rows.map(&:line)).to eq([ Diff::Line.new(":id number", "no_change", 1) ])
    end

    it "marks a changed kind as type_changed" do
      diff = DiffParams::FromParams.new([ param("id", "string") ], [ param("id", "number") ])
      expect(diff.after_rows.map(&:line)).to eq([ Diff::Line.new(":id number", "type_changed", 1) ])
    end

    it "marks every param as added when there is no previous endpoint" do
      diff = DiffParams::FromParams.new([], [ param("id", "number") ])
      expect(diff.after_rows.map(&:line)).to eq([ Diff::Line.new(":id number", "added", 1) ])
    end

    it "pads the names so the kinds line up" do
      diff = DiffParams::FromParams.new([], [ param("postId", "number"), param("slug", "string") ])

      expect(diff.after_rows.map(&:line)).to eq([
        Diff::Line.new(":postId number", "added", 1),
        Diff::Line.new(":slug   string", "added", 1)
      ])
    end

    it "names each row, so a comment can anchor to the param" do
      diff = DiffParams::FromParams.new([], [ param("postId", "number"), param("slug", "string") ])
      expect(diff.after_rows.map(&:name)).to eq([ "postId", "slug" ])
    end

    it "drops a removed param, which has no after side" do
      diff = DiffParams::FromParams.new([ param("id", "number") ], [])
      expect(diff.after_rows).to eq([])
    end
  end

  describe "#before_rows" do
    it "holds the previous kind" do
      diff = DiffParams::FromParams.new([ param("id", "string") ], [ param("id", "number") ])
      expect(diff.before_rows.map(&:line)).to eq([ Diff::Line.new(":id string", "type_changed", 1) ])
    end

    it "marks every param as removed when the endpoint is gone" do
      diff = DiffParams::FromParams.new([ param("id", "number") ], [])
      expect(diff.before_rows.map(&:line)).to eq([ Diff::Line.new(":id number", "removed", 1) ])
    end

    it "drops an added param, which has no before side" do
      diff = DiffParams::FromParams.new([], [ param("id", "number") ])
      expect(diff.before_rows).to eq([])
    end
  end

  describe "Row#removed?" do
    it "is true only for a param the new side dropped" do
      diff = DiffParams::FromParams.new([ param("id", "number"), param("slug", "string") ], [ param("id", "number") ])

      expect(diff.before_rows.map { |row| [ row.name, row.removed? ] }).to eq([ [ "id", false ], [ "slug", true ] ])
    end
  end
end

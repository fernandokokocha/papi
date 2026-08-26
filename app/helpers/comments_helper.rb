module CommentsHelper
  # Complete literal class strings so Tailwind sees them. Kinds echo the app's
  # card colors (endpoint sky, entity violet) plus non-semantic hues; all clear
  # of the red / green / amber that already mean removed / added / changed
  # (fuchsia, not pink, so response never reads as red; slate for input, because
  # every remaining saturated hue sits next to a diff color or to note's cyan).
  KIND_STYLES = {
    line:          { label: "Line",          bg: "bg-indigo-50/60",  rail: "border-l-indigo-500",  chip: "bg-indigo-100 text-indigo-700 border-indigo-200" },
    response:      { label: "Response",      bg: "bg-fuchsia-50/60", rail: "border-l-fuchsia-500", chip: "bg-fuchsia-100 text-fuchsia-700 border-fuchsia-200" },
    note:          { label: "Note",          bg: "bg-cyan-50/60",    rail: "border-l-cyan-500",    chip: "bg-cyan-100 text-cyan-700 border-cyan-200" },
    input:         { label: "Input",         bg: "bg-slate-50/60",   rail: "border-l-slate-500",   chip: "bg-slate-100 text-slate-700 border-slate-200" },
    param:         { label: "Param",         bg: "bg-teal-50/60",    rail: "border-l-teal-500",    chip: "bg-teal-100 text-teal-700 border-teal-200" },
    endpoint:      { label: "Endpoint",      bg: "bg-sky-50/60",     rail: "border-l-sky-600",     chip: "bg-sky-100 text-sky-700 border-sky-200" },
    entity:        { label: "Entity",        bg: "bg-violet-50/60",  rail: "border-l-violet-600",  chip: "bg-violet-100 text-violet-700 border-violet-200" },
    auth:          { label: "Auth",          bg: "bg-stone-50/60",   rail: "border-l-stone-500",   chip: "bg-stone-100 text-stone-700 border-stone-200" },
    release_notes: { label: "Release notes", bg: "bg-purple-50/60",  rail: "border-l-purple-600",  chip: "bg-purple-100 text-purple-700 border-purple-200" },
    conversation:  { label: "Conversation",  bg: "bg-blue-50/60",    rail: "border-l-blue-600",    chip: "bg-blue-100 text-blue-700 border-blue-200" }
  }.freeze

  def comment_kind_style(kind)
    KIND_STYLES.fetch(kind)
  end

  def candidate_comments
    @candidate_comments ||= CandidateComments.for(@candidate)
  end

  def can_comment?
    return @can_comment unless @can_comment.nil?

    @can_comment = @candidate.present? && policy(Comment.new(candidate: @candidate)).create?
  end

  def sidebar_count_dom_id(anchor)
    "sidebar_count_#{anchor.dom_id}"
  end

  def sidebar_count_badge(anchor, css_class: "ml-auto shrink-0")
    return "".html_safe unless @candidate
    tag.span(render("comments/count_badge", count: candidate_comments.sidebar_count(anchor)),
             id: sidebar_count_dom_id(anchor), class: css_class)
  end

  def line_index_for(lines, entities)
    return nil unless @candidate

    ExpandedLineIndex.new(lines, entities).to_a
  end
end

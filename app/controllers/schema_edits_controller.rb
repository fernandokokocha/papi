class SchemaEditsController < ApplicationController
  def create
    submitted = SchemaForm::Blocks.from(params[:blocks])
    block = submitted.fetch(params[:id])
    root = SchemaForm::Operation.new(submitted.parse(block), submitted.version.entities)
      .apply(params[:op], Array(params[:path]), params[:value])

    edited = submitted.replacing(block.id, root.serialize)

    render turbo_stream: edited.changed_since(submitted).map { |changed|
      turbo_stream.replace(changed.id, partial: "schema_form/editor", locals: edited.locals_for(changed))
    }
  end
end

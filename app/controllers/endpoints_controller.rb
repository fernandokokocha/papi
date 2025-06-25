class EndpointsController < ApplicationController
  def show
    @project = Project.find_by(name: params[:project_name])
    puts @project.inspect
    @version = Version.find_by(name: params[:version_name], project: @project)
    puts @version.inspect
    @endpoint = Endpoint.find_by(id: params[:id], version: @version)
    puts @endpoint.inspect

    authorize @endpoint
    previous_endpoint = @version.previous&.endpoints.where(url: @endpoint.url, http_verb: @endpoint.http_verb).first

    expanded = params[:expanded].nil? ? true : parse_expanded(params[:expanded])
    if expanded
      input_diff = Diff::FromValues.new(previous_endpoint.input.expand, @endpoint.input.expand)
      output_diff = Diff::FromValues.new(previous_endpoint.output.expand, @endpoint.output.expand)
    else
      input_diff = Diff::FromValues.new(previous_endpoint.input, @endpoint.input)
      output_diff = Diff::FromValues.new(previous_endpoint.output, @endpoint.output)
    end

    render partial: "versions/endpoint_diff",
           layout: false,
           locals: { endpoint: @endpoint, input_diff: input_diff, output_diff: output_diff, expanded: expanded }
  end

  private

  def parse_expanded(expanded)
    expanded != "false"
  end
end

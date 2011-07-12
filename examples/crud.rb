class Crud < Kepi::Api

  endpoint :get, "/resource/:id" do |e|
    e.description = "Get the resource with given id"
    #e.required_param :id, Integer

    e.on_action do |req, e|
      "Here is your resource: #{req.params['id']}"
    end
  end

  endpoint :put, "/resource/:id" do |e|
    e.description = "Update the resource with given id"
    e.required_param :id,   Integer
    e.optional_param :name, String

    e.on_action do |req, e|
      "Here is your updated resource: #{req.params['id']}"
    end
  end
end

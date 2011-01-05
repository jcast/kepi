class Crud < Kepi::Api

  endpoint :get, "resource/:id" do |e|
    e.description = "Get the resource with given id"
    e.mandatory_param :id, /^\d+$/

    e.on_action do |req, e|
      "Here is your resource: #{req.params['id']}"
    end
  end
end

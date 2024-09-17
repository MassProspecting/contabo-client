require 'net/http'
require 'json'
require 'uri'
require 'pry'

class ContaboClient  
  def initialize(
    client_id:,
    client_secret:,
    api_user:, 
    api_password:
)
    @client_id = CLIENT_ID
    @client_secret = CLIENT_SECRET
    @api_user = API_USER
    @api_password = API_PASSWORD
    @auth_url = 'https://auth.contabo.com/auth/realms/contabo/protocol/openid-connect/token'
    @api_url = 'https://api.contabo.com/v1/compute/instances'
  end

  def get_access_token
    uri = URI(@auth_url)
    response = Net::HTTP.post_form(uri, {
      'client_id' => @client_id,
      'client_secret' => @client_secret,
      'username' => @api_user,
      'password' => @api_password,
      'grant_type' => 'password'
    })
    JSON.parse(response.body)['access_token']
  end

  def create_secret(password)
    access_token = get_access_token
  
    uri = URI('https://api.contabo.com/v1/secrets')
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'
    request['x-request-id'] = SecureRandom.uuid
  
    body = {
      name: "Ruby's Contabo Client #{SecureRandom.uuid}",
      value: password,
      type: "password"
    }
  
    request.body = body.to_json
  
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
   
    # Debugging: Print the full response
    puts "Response code: #{response.code}"
    puts "Response body: #{response.body}"
   
    data = JSON.parse(response.body)['data'].first
    raise "Failed to create secret. Error: #{response.body}" if data.nil?
    data['secretId']
  end

  def retrieve_images(page: 1, size: 10)
    access_token = get_access_token
    uri = URI('https://api.contabo.com/v1/compute/images')
    params = { page: page, size: size }
    uri.query = URI.encode_www_form(params)
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['x-request-id'] = SecureRandom.uuid
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    JSON.parse(response.body)
  end
  
  def get_instances(page: 1, size: 10, order_by: nil)
    access_token = get_access_token

    uri = URI(@api_url)
    params = { page: page, size: size }
    params[:orderBy] = order_by if order_by
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['x-request-id'] = SecureRandom.uuid

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    puts JSON.parse(response.body)['network']['ipAddress']
    JSON.parse(response.body)
  end

  def create_instance(image_id:, product_id:, region: 'EU', root_password:, display_name:, cloud_init: nil)
    access_token = get_access_token
  
    uri = URI(@api_url)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'
    request['x-request-id'] = SecureRandom.uuid
  
    body = {
      imageId: image_id,
      productId: product_id,
      region: region,
      rootPassword: root_password,
      displayName: display_name,
      cloudInit: cloud_init
    }.compact # Remove nil values if cloudInit is not provided
  
    request.body = body.to_json
  
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  
    JSON.parse(response.body)
  end
  
  def reinstall_instance(instance_id:, image_id:, root_password:)
    access_token = get_access_token
  
    uri = URI("https://api.contabo.com/v1/compute/instances/#{instance_id}")
    request = Net::HTTP::Put.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'
    request['x-request-id'] = SecureRandom.uuid
  
    body = {
      imageId: image_id,
      rootPassword: root_password
    }
  
    request.body = body.to_json
  
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  
    def cancel_instance(instance_id:)
      # Construct the URL for the cancellation request
      url = "#{@base_url}/instances/#{instance_id}"
  
      # Send the DELETE request
      response = RestClient.delete(
        url,
        {
          Authorization: "Bearer #{get_access_token}",
          accept: :json
        }
      )
  
      # Parse the response
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      # Handle any API errors gracefully
      puts "Error canceling instance: #{e.response}"
      JSON.parse(e.response.body) # Optional: Parse and return error details
    end
    
    JSON.parse(response.body)
  end        
end

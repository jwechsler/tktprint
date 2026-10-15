class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods
  
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  TICKET_TOKEN = 'lslslslslsslmjfaiemfksufsa93mfvl9s03z345s'

  def token
    authenticate_with_http_basic do |username, password|
      if username.eql?($XML_AUTHORIZATION['username']) && password.eql?($XML_AUTHORIZATION['password'])
        render json: { token: TICKET_TOKEN }
      else
        render json: { error: 'Incorrect credentials' , status: 401 }
      end
    end
  end

  protected
  def authorize
    authenticate_or_request_with_http_basic do |username, password|
      username == $XML_AUTHORIZATION['username'] && password == $XML_AUTHORIZATION['password']
    end
  end
end

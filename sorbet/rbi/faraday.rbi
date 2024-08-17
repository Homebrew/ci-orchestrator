# typed: strong

class Faraday::Error
  sig { returns(T.nilable(String)) }
  def response_body; end
end

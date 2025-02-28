# typed: strong

class Faraday::Error
  sig { returns(T.nilable(String)) }
  def response_body; end
end

class Faraday::Request
  Elem = type_member(:out) {{fixed: T.untyped}}

  sig { returns(Faraday::RequestOptions) }
  def options; end
end

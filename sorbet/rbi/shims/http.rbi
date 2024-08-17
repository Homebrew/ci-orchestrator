
# typed: strong

# https://github.com/sorbet/sorbet/pull/8153
class Net::HTTP
  sig { params(uri_or_host: URI::Generic).returns(T.nilable(String)) }
  sig { params(uri_or_host: URI::Generic, path_or_header: T.nilable(T::Hash[T.any(String, Symbol), String])).returns(T.nilable(String)) }
  sig { params(uri_or_host: String, path_or_header: String, port: T.nilable(Integer)).returns(T.nilable(String)) }
  def self.get(uri_or_host, path_or_header, port=nil); end
end

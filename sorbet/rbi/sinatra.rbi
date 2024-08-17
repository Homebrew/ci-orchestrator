# typed: strong

class Sinatra::Base
  class << self
    sig { params(name: String, block: T.proc.bind(Sinatra::Base).returns(T::Boolean)).void }
    def condition(name = T.unsafe(nil), &block); end

    sig { params(path: String, opts: T::Hash[Symbol, T.untyped], block: Proc).void }
    def head(path, opts = {}, &block); end

    sig { params(path: String, opts: T::Hash[Symbol, T.untyped], block: Proc).void }
    def get(path, opts = {}, &block); end

    sig { params(path: String, opts: T::Hash[Symbol, T.untyped], block: Proc).void }
    def link(path, opts = {}, &block); end

    sig { params(path: String, opts: T::Hash[Symbol, T.untyped], block: Proc).void }
    def options(path, opts = {}, &block); end

    sig { params(path: String, opts: T::Hash[Symbol, T.untyped], block: Proc).void }
    def patch(path, opts = {}, &block); end

    sig { params(path: String, opts: T::Hash[Symbol, T.untyped], block: Proc).void }
    def post(path, opts = {}, &block); end

    sig { params(path: String, opts: T::Hash[Symbol, T.untyped], block: Proc).void }
    def put(path, opts = {}, &block); end

    sig { params(option: T::Enumerable[[T.any(Symbol, String), T.untyped]]).returns(T.self_type) }
    sig { params(option: T.any(Symbol, String), value: T.untyped, ignore_setter: T::Boolean).returns(T.self_type) }
    sig { params(option: T.any(Symbol, String), ignore_setter: T::Boolean, block: Proc).returns(T.self_type) }
    def set(option, value = nil, ignore_setter = false, &block); end

    sig { params(path: String, opts: T::Hash[Symbol, T.untyped], block: Proc).void }
    def unlink(path, opts = {}, &block); end
  end

  sig { returns(Sinatra::IndifferentHash) }
  def params; end

  sig { returns(Sinatra::Request) }
  def request; end

  sig { returns(T::Hash[T.untyped, T.untyped]) }
  def session; end

  sig { returns(T.class_of(Sinatra::Base)) }
  def settings; end
end

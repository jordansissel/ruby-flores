require "randomized"
require "socket"
require "rspec/stress_it"

RSpec.configure do |c|
  c.extend RSpec::StressIt
end

# A factory for encapsulating behavior of a tcp server and client for the
# purposes of testing.
#
# This is probably not really a "factory" in a purist-sense, but whatever.
class TCPIntegrationTestFactory
  def initialize(port)
    @listener = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    @client = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    @port = port
  end

  def teardown
    @listener.close unless @listener.closed?
    @client.close unless @listener.closed?
  end

  def sockaddr
    Socket.sockaddr_in(@port, "127.0.0.1")
  end

  def setup
    @listener.bind(sockaddr)
    @listener.listen(5)
  end

  def send_and_receive(text)
    @client.connect(sockaddr)
    server, _ = @listener.accept

    @client.syswrite(text)
    @client.close
    server.read
  ensure
    @client.close unless @client.closed?
    server.close unless server.nil? || server.closed?
  end
end

describe "TCPServer+TCPSocket" do
  let(:port) { Randomized.number(1024..65535) }
  let(:text) { Randomized.text(1..10000) }
  subject { TCPIntegrationTestFactory.new(port) }
  
  describe "using stress_it" do
    stress_it "should send data correctly" do
      begin
        subject.setup
      rescue Errno::EADDRINUSE
        next # Skip port bindings that are in use
      end

      begin
        received = subject.send_and_receive(text)
        expect(received).to(be == text)
      ensure
        subject.teardown
      end
    end
  end
end

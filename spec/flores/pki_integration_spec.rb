# encoding: utf-8
# This file is part of ruby-flores.
# Copyright (C) 2015 Jordan Sissel
# 
require "spec_init"
require "flores/pki"

describe "PKI Integration" do
  let(:csr) { Flores::PKI::CertificateSigningRequest.new }
  # Here, I use a 1024-bit key for faster tests. 
  # Please do not use such small keys in production.
  let(:key_bits) { 1024 }
  let(:key) { OpenSSL::PKey::RSA.generate(key_bits, 65537) }
  let(:certificate_duration) { Flores::Random.number(1..86400) }

  context "with self-signed client/server certificate" do
    let(:certificate_subject) { "CN=server.example.com" }
    let(:certificate) { csr.create }

    # Returns [socket, address, port]
    let(:listener) { Flores::Random.tcp_listener }
    let(:server) { listener[0] }
    let(:server_address) { listener[1] }
    let(:server_port) { listener[2] }

    let(:server_context) { OpenSSL::SSL::SSLContext.new }
    let(:client_context) { OpenSSL::SSL::SSLContext.new }

    before do
      #Thread.abort_on_exception = true
      csr.subject = certificate_subject
      csr.public_key = key.public_key
      csr.start_time = Time.now
      csr.expire_time = csr.start_time + certificate_duration
      csr.signing_key = key
      csr.want_signature_ability = true

      server_context.cert = certificate
      server_context.key = key
      server_context.ssl_version = :TLSv1
      server_context.verify_mode =  OpenSSL::SSL::VERIFY_NONE

      client_store = OpenSSL::X509::Store.new
      client_store.add_cert(certificate)
      client_context.cert_store = client_store
      client_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
      client_context.ssl_version = :TLSv1

      ssl_server = OpenSSL::SSL::SSLServer.new(server, server_context)
      Thread.new do
        begin
          ssl_server.accept
        rescue => e
          puts "Server accept failed: #{e}"
        end
      end
    end

    it "should successfully connect as a client" do
      socket = TCPSocket.new(server_address, server_port)
      ssl_client = OpenSSL::SSL::SSLSocket.new(socket, client_context)
      ssl_client.connect
    end
  end
end

# encoding: utf-8
# This file is part of ruby-flores.
# Copyright (C) 2015 Jordan Sissel
# 
require "spec_init"
require "flores/pki"

describe Flores::PKI::CertificateSigningRequest do
  let(:csr) { Flores::PKI::CertificateSigningRequest.new }

  # Here, I use a 512-bit key for faster tests. 
  # Please do not use 512-bit keys in production.
  let(:key_bits) { 512 }

  let(:key) { OpenSSL::PKey::RSA.generate(key_bits, 65537) }
  let(:certificate_duration) { Flores::Random.number(1..86400) }

  #before do
    #csr.subject = "OU=Fancy Pants Co."
    #csr.public_key = root_key.public_key
    #csr.start_time = Time.now
    #csr.expire_time = csr.start_time + certificate_duration
  #end

  shared_examples_for "a certificate" do
    it "returns a valid certificate" do
      expect(certificate).to(be_a(OpenSSL::X509::Certificate))
    end
  end

  context "#subject=" do
    context "with an invalid subject" do
      let(:certificate_subject) { Flores::Random.text(1..20) }
      it "fails" do
        expect { csr.subject = certificate_subject }.to(raise_error(Flores::PKI::CertificateSigningRequest::InvalidSubject))
      end
    end
  end

  context "a self-signed client/server certificate" do
    let(:certificate_subject) { "CN=server.example.com" }
    before do
      csr.subject = certificate_subject
      csr.public_key = key.public_key
      csr.start_time = Time.now
      csr.expire_time = csr.start_time + certificate_duration
      csr.signing_key = key
    end
    let(:certificate) { csr.create }
    it_behaves_like "a certificate"
  end
end

describe Flores::PKI do
  context ".random_serial" do
    let(:serial) { Flores::PKI.random_serial }
    stress_it "generates a valid OpenSSL::BN value" do
      OpenSSL::BN.new(serial)
      Integer(serial)
    end
  end

  context ".generate" do
    it "returns a certificate and a key" do
      certificate, key = Flores::PKI.generate
      expect(certificate).to(be_a(OpenSSL::X509::Certificate))
      expect(key).to(be_a(OpenSSL::PKey::RSA))
    end
  end
end

# encoding: utf-8
# This file is part of ruby-flores.
# Copyright (C) 2015 Jordan Sissel
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
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

    it "validates" do
      expect(certificate.verify(certificate.public_key)).to be_truthy
    end
  end

  context "certificate signed by a single CA" do
    let(:csr_ca) {Flores::PKI::CertificateSigningRequest.new}
    let(:csr_server) {Flores::PKI::CertificateSigningRequest.new}
    let(:ca_key) {OpenSSL::PKey::RSA.generate(key_bits, 65537)}
    let(:ca_subject) {"CN=ca.example.com"}
    let(:server_subject) {"CN=server.example.com"}

    before do
      #request signing cert (a self signed cert)
      csr_ca.subject = ca_subject
      csr_ca.public_key = ca_key.public_key
      csr_ca.start_time = Time.now
      csr_ca.expire_time = csr_ca.start_time + certificate_duration
      csr_ca.signing_key = ca_key
      csr_ca.want_signature_ability = true

      #request the server cert
      csr_server.subject = server_subject
      csr_server.public_key = key.public_key
      csr_server.start_time = Time.now
      csr_server.expire_time = csr_server.start_time + certificate_duration
      csr_server.signing_key = ca_key
      csr_server.signing_certificate = ca_certificate
    end
    let(:certificate) {csr_server.create}
    let(:ca_certificate) {csr_ca.create}

    it_behaves_like "a certificate"

    it "validates signatures" do
      expect(ca_certificate.verify(ca_certificate.public_key)).to be_truthy
      expect(certificate.verify(ca_certificate.public_key)).to be_truthy
    end

    it "validates certificate chain" do
      store = OpenSSL::X509::Store.new
      store.add_cert(ca_certificate)
      expect(store.verify(certificate))
    end
  end

  context "certificate signed by an intermediate CA" do
    let(:csr_ca) {Flores::PKI::CertificateSigningRequest.new}
    let(:csr_ca_intermediate) {Flores::PKI::CertificateSigningRequest.new}
    let(:csr_server) {Flores::PKI::CertificateSigningRequest.new}
    let(:ca_key) {OpenSSL::PKey::RSA.generate(key_bits, 65537)}
    let(:ca_intermediate_key) {OpenSSL::PKey::RSA.generate(key_bits, 65537)}
    let(:ca_subject) {"CN=ca.example.com"}
    let(:ca_intermediate_subject) {"CN=intermediate.ca.example.com"}
    let(:server_subject) {"CN=server.example.com"}

    before do
      #request the root signing cert (a self signed cert)
      csr_ca.subject = ca_subject
      csr_ca.public_key = ca_key.public_key
      csr_ca.start_time = Time.now
      csr_ca.expire_time = csr_ca.start_time + certificate_duration
      csr_ca.signing_key = ca_key # <-- self signed
      csr_ca.want_signature_ability = true

      #request the intermediate signing cert
      csr_ca_intermediate.subject = ca_intermediate_subject
      csr_ca_intermediate.public_key = ca_intermediate_key.public_key
      csr_ca_intermediate.start_time = Time.now
      csr_ca_intermediate.expire_time = csr_ca_intermediate.start_time + certificate_duration
      csr_ca_intermediate.signing_key = ca_key # <-- signed by root
      csr_ca_intermediate.want_signature_ability = true
      csr_ca_intermediate.signing_certificate = ca_certificate

      #request the server cert
      csr_server.subject = server_subject
      csr_server.public_key = key.public_key
      csr_server.start_time = Time.now
      csr_server.expire_time = csr_server.start_time + certificate_duration
      csr_server.signing_key = ca_intermediate_key #<-- signed by intermediate
      csr_server.signing_certificate = ca_intermediate_certificate
    end
    let(:certificate) {csr_server.create}
    let(:ca_certificate) {csr_ca.create}
    let(:ca_intermediate_certificate) {csr_ca_intermediate.create}

    it_behaves_like "a certificate"

    it "validates signatures" do
      expect(ca_certificate.verify(ca_certificate.public_key)).to be_truthy
      expect(ca_intermediate_certificate.verify(ca_certificate.public_key)).to be_truthy
      expect(certificate.verify(ca_intermediate_certificate.public_key)).to be_truthy
    end

    it "validates certificate chain" do
      store = OpenSSL::X509::Store.new
      store.add_cert(ca_certificate)
      store.add_cert(ca_intermediate_certificate)
      expect(store.verify(certificate)).to be_truthy
    end
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

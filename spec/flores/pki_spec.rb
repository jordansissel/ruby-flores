require "flores/pki"

describe Flores::PKI::CertificateSigningRequest do
  let(:csr) { Flores::PKI::CertificateSigningRequest.new }

  # Using a 512-bit key for speedier tests. 
  # Please do not use 512-bit keys in production.
  let(:key_bits) { 512 }
  let(:root_key) { OpenSSL::PKey::RSA.generate(key_bits, 65537) }

  let(:certificate_duration) { Flores::Random.number(1..86400) }

  before do
    csr.subject = "OU=Fancy Pants Co."
    csr.public_key = root_key.public_key
    csr.start_time = Time.now
    csr.expire_time = csr.start_time + certificate_duration
  end

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

  context "#create_ca" do
    let(:certificate) { csr.create_root(root_key) }
    it_behaves_like "a certificate"
  end

  context "#create_intermediate" do
    let(:root_ca) { csr.create_root(root_key) }
    let(:key) { OpenSSL::PKey::RSA.generate(key_bits, 65537) }
    let(:intermediate_csr) { Flores::PKI::CertificateSigningRequest.new }
    let(:certificate) { intermediate_csr.create_intermediate(root_ca, root_key) }
    before do
      intermediate_csr.subject = "OU=Fancy Pants Co. Intermediate 1"
      intermediate_csr.public_key = key.public_key
      intermediate_csr.start_time = Time.now
      intermediate_csr.expire_time = intermediate_csr.start_time + certificate_duration
    end
    it_behaves_like "a certificate"
  end

  context "#create" do
    let(:root_ca) { csr.create_root(root_key) }
    let(:key) { OpenSSL::PKey::RSA.generate(key_bits, 65537) }
    let(:server_csr) { Flores::PKI::CertificateSigningRequest.new }
    let(:certificate) { server_csr.create(root_ca, root_key) }
    before do
      server_csr.subject = "CN=server.example.com"
      server_csr.public_key = key.public_key
      server_csr.start_time = Time.now
      server_csr.expire_time = server_csr.start_time + certificate_duration
    end

    it_behaves_like "a certificate"
  end

  context "#create_self_signed" do
    before do
      csr.subject = "CN=example.com"
    end
    let(:certificate) { csr.create_self_signed(root_key) }
    it_behaves_like "a certificate"
  end
end

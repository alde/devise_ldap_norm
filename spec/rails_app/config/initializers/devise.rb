Devise.setup do |config|
  config.mailer_sender = "please-change-me-at-config-initializers-devise@example.com"

  if ::Devise.respond_to?(:secret_key)
    ::Devise.secret_key = '012a16191a7f61e84e55704e34b73db991a23ba396b6b7760596a3e80073e4464c55421c42a1a34327dee44828bec6745c48eba10cc0866799ec95c09ea27ada'
  end

  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 10
  config.reconfirmable = true
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete
end

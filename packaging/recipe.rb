class ProxyMgr < FPM::Cookery::Recipe
  homepage    'http://github.com/campanja/proxymgr'
  name        'proxymgr'
  version     '0.1'
  source      'none', :with => :noop

  revision    '1'
  vendor      'campanja'
  maintainer  'Team Omega <omega@campanja.com>'
  license     'MIT'

  description 'Manages Haproxy configuration dynamically'
  section     'admin'

  depends 'ruby2.1', 'haproxy (>= 1.5)'

  def build
    File.open('Gemfile', 'w') do |fh|
      fh.puts <<-EOF
source "https://rubygems.org"

gem '#{name}', '0.1', :git => 'git@github.com:campanja/proxymgr.git'
EOF
    end
    system 'bundle install --binstubs --standalone --path vendor/bundle'
  end

  def install
    opt('proxymgr').install Dir['*']
    opt('proxymgr').install Dir['.bundle']
    etc('profile.d').install(workdir('profile.sh'), 'proxymgr.sh')
  end
end

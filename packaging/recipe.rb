class ProxyMgr < FPM::Cookery::Recipe
  gemspec = eval(File.read('../proxymgr.gemspec'))

  homepage    'http://github.com/campanja/proxymgr'
  name        'proxymgr'
  version     gemspec.version.to_s
  source      'none', :with => :noop

  revision    '1'
  vendor      'campanja'
  maintainer  'Team Omega <omega@campanja.com>'
  license     'APL 2.0'

  description 'Manages Haproxy configuration dynamically'
  section     'admin'

  depends 'ruby2.1', 'haproxy (>= 1.5)'

  def build
    File.open('Gemfile', 'w') do |fh|
      fh.puts <<-EOF
source "https://rubygems.org"

gem '#{name}', '#{version}', :git => 'git@github.com:campanja/proxymgr.git'
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

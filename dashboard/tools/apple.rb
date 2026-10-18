require 'openssl'
require 'net/http'
require 'json'
require 'base64'
require 'uri'
require 'time'
AUTH = JSON.parse(File.read(ENV.fetch('ASC_METADATA', '/Users/tanyasmritivictorcharles/Documents/FindEZ/AppStore/1.0.7-review-fix/apple-api-metadata.json')))
KEY = OpenSSL::PKey.read(File.read(File.expand_path("~/.private_keys/AuthKey_#{AUTH.fetch('key_id')}.p8")))
BASE = 'https://api.appstoreconnect.apple.com'
BUNDLE = 'com.findez.dashboard'
APP = '6824178526'
EMAIL = 'tanyasmritivictorcharles@gmail.com'
GROUP = 'Founder Private'
def token
  encode = ->(s) { Base64.urlsafe_encode64(s, padding: false) }
  data = [encode.call(JSON.generate({alg: 'ES256', kid: AUTH.fetch('key_id'), typ: 'JWT'})),
          encode.call(JSON.generate({iss: AUTH.fetch('issuer_id'), iat: Time.now.to_i, exp: Time.now.to_i + 1100, aud: 'appstoreconnect-v1'}))].join('.')
  sig = KEY.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(data))
  parts = OpenSSL::ASN1.decode(sig).value.map { |v| v.value.to_s(2).rjust(32, "\x00") }.join
  data + '.' + encode.call(parts)
end

def api(method, path, payload = nil)
  uri = URI(path.start_with?('https://') ? path : BASE + path)
  raise 'Unexpected API host' unless uri.scheme == 'https' && uri.host == 'api.appstoreconnect.apple.com'
  request = Net::HTTP.const_get(method.capitalize).new(uri)
  request['Authorization'] = 'Bearer ' + token
  request['Content-Type'] = 'application/json'
  request.body = JSON.generate(payload) if payload
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 40) { |http| http.request(request) }
  result = response.body && !response.body.empty? ? JSON.parse(response.body) : {}
  if response.code.to_i >= 300
    raise "API #{method} #{uri.path} #{response.code}: #{JSON.generate(result.fetch('errors', []).map { |e| e.slice('status', 'code', 'title', 'detail') })}"
  end
  result
end

def list(path)
  results = []
  loop do
    response = api('get', path)
    results.concat(response.fetch('data'))
    path = response.dig('links', 'next')
    break unless path
  end
  results
end


case ARGV.fetch(0)
when 'tester-check'
  emails = [EMAIL, 'vinodrex@gmail.com']
  users = list('/v1/users').select { |u| emails.include?(u.dig('attributes','username').to_s.downcase) }
  testers = emails.flat_map { |email| list('/v1/betaTesters?filter[email]=' + URI.encode_www_form_component(email)) }
  groups = list("/v1/betaGroups?filter[app]=#{APP}")
  puts JSON.pretty_generate({users:users.map { |u| {id:u['id'],attributes:u['attributes']} },testers:testers.map { |u| {id:u['id'],attributes:u['attributes']} },groups:groups})
when 'preflight'
  bundles = list("/v1/bundleIds?filter[identifier]=#{BUNDLE}")
  apps = list("/v1/apps?filter[bundleId]=#{BUNDLE}")
  users = list('/v1/users').select { |u| u.dig('attributes','username').to_s.downcase == 'tanyasmritivictorcharles@gmail.com' }
  puts JSON.pretty_generate({bundles: bundles, apps: apps, founder_apple_users: users.map { |u| u.slice('id','attributes') }})
when 'register'
  bundles = list("/v1/bundleIds?filter[identifier]=#{BUNDLE}")
  raise 'Duplicate bundle identities' if bundles.length > 1
  bundle = bundles.first || api('post','/v1/bundleIds',{data:{type:'bundleIds',attributes:{identifier:BUNDLE,name:'FindEZ Dashboard',platform:'IOS'}}}).fetch('data')
  puts JSON.pretty_generate(bundle)
when 'tester-status'
  puts JSON.pretty_generate(list("/v1/betaTesters?filter[email]=#{EMAIL}").map { |t| t.slice('id','attributes') })
when 'beta-status', 'beta-prepare'
  app = api('get', "/v1/apps/#{APP}").fetch('data')
  raise 'Wrong app' unless app.dig('attributes','bundleId') == BUNDLE
  groups = list("/v1/betaGroups?filter[app]=#{APP}")
  group = groups.find { |g| g.dig('attributes','name') == GROUP }
  if ARGV[0] == 'beta-prepare'
    group ||= api('post','/v1/betaGroups',{data:{type:'betaGroups',attributes:{name:GROUP,isInternalGroup:true,publicLinkEnabled:false,hasAccessToAllBuilds:false,feedbackEnabled:true},relationships:{app:{data:{type:'apps',id:APP}}}}}).fetch('data')
    raise 'Group is not private internal testing' unless group.dig('attributes','isInternalGroup') == true && !group.dig('attributes','publicLinkEnabled')
    testers = list("/v1/betaTesters?filter[email]=#{EMAIL}")
    tester = testers.find { |t| t.dig('attributes','inviteType') == 'INTERNAL' }
    tester ||= testers.first if testers.length == 1
    tester ||= api('post','/v1/betaTesters',{data:{type:'betaTesters',attributes:{email:EMAIL,firstName:'Tanya',lastName:'Charles'},relationships:{betaGroups:{data:[{type:'betaGroups',id:group.fetch('id')}]}}}}).fetch('data')
    current = list("/v1/betaGroups/#{group.fetch('id')}/betaTesters")
    raise 'Unexpected tester in private group' unless current.all? { |t| t.dig('attributes','email').to_s.downcase == EMAIL }
    unless current.any? { |t| t['id'] == tester['id'] }
      api('post',"/v1/betaGroups/#{group.fetch('id')}/relationships/betaTesters",{data:[{type:'betaTesters',id:tester.fetch('id')}]})
    end
  end
  builds = list("/v1/builds?filter[app]=#{APP}&sort=-uploadedDate&limit=5")
  members = group ? list("/v1/betaGroups/#{group.fetch('id')}/betaTesters") : []
  puts JSON.pretty_generate({app_id:APP,bundle:BUNDLE,group:group,members:members.map { |t| {id:t['id'],email:t.dig('attributes','email')} },builds:builds})
when 'beta-release'
  app = api('get', "/v1/apps/#{APP}").fetch('data')
  raise 'Wrong app' unless app.dig('attributes','bundleId') == BUNDLE
  builds = list("/v1/builds?filter[app]=#{APP}&filter[version]=2")
  raise 'Expected one build 2' unless builds.length == 1
  build = builds.first
  raise 'Build is not valid' unless build.dig('attributes','processingState') == 'VALID'
  pre = api('get',"/v1/builds/#{build.fetch('id')}/preReleaseVersion").fetch('data')
  raise 'Wrong version' unless pre.dig('attributes','version') == '1.0.0'
  groups = list("/v1/betaGroups?filter[app]=#{APP}")
  group = groups.find { |g| g.dig('attributes','name') == GROUP } || raise('Prepare private group first')
  raise 'Unexpected additional groups' unless groups.length == 1
  members = list("/v1/betaGroups/#{group.fetch('id')}/betaTesters")
  raise 'Expected only founder' unless members.length == 1 && members.first.dig('attributes','email').to_s.downcase == EMAIL
  notes = list("/v1/builds/#{build.fetch('id')}/betaBuildLocalizations")
  description = 'Private founder dashboard. Sign in with your FindEZ password or request an email code. Check Overview, Issues, Customers and More. Verify refresh, issue status and launch priorities. Revenue, activity, AI cost and quality metrics show unavailable when no real source is connected. This build is for the authorized founder only.'
  unless notes.any? { |n| n.dig('attributes','locale') == 'en-US' }
    api('post','/v1/betaBuildLocalizations',{data:{type:'betaBuildLocalizations',attributes:{locale:'en-US',whatsNew:description},relationships:{build:{data:{type:'builds',id:build.fetch('id')}}}}})
  end
  assigned = list("/v1/betaGroups/#{group.fetch('id')}/builds")
  unless assigned.any? { |b| b['id'] == build['id'] }
    api('post',"/v1/betaGroups/#{group.fetch('id')}/relationships/builds",{data:[{type:'builds',id:build.fetch('id')}]})
  end
  beta = api('get',"/v1/builds/#{build.fetch('id')}/buildBetaDetail").fetch('data')
  puts JSON.pretty_generate({app_id:APP,build:build,group:group,members:members.map { |t| {id:t['id'],email:t.dig('attributes','email')} },beta:beta,app_store_not_submitted:true})
else
  raise 'Unknown operation'
end
